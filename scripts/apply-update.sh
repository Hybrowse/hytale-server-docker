#!/bin/sh
set -eu

log() { printf '%s\n' "Update: $*" >&2; }
fail() { log "ERROR: $*"; exit 1; }
DATA_DIR="${DATA_DIR:-/data}"
SERVER_DIR="${DATA_DIR}/server"
updater="${DATA_DIR}/updater"
staging="${updater}/staging"
transaction="${updater}/image-transaction"
backup="${updater}/image-backup"
items='jar assets aotconfig aot licenses'

destination() {
  case "$1" in
    jar) printf '%s/server/HytaleServer.jar' "${DATA_DIR}" ;;
    assets) printf '%s/Assets.zip' "${DATA_DIR}" ;;
    aotconfig) printf '%s/server/HytaleServer.aot.config' "${DATA_DIR}" ;;
    aot) printf '%s/server/HytaleServer.aot' "${DATA_DIR}" ;;
    licenses) printf '%s/server/Licenses' "${DATA_DIR}" ;;
  esac
}

check_paths() {
  for path in "${SERVER_DIR}" "${updater}" "${staging}" "${transaction}" "${backup}"; do
    [ ! -L "${path}" ] || fail "Refusing symbolic link: ${path}"
  done
  for item in ${items}; do
    path="$(destination "${item}")"
    [ ! -L "${path}" ] || fail "Refusing symbolic link: ${path}"
    if [ -e "${path}" ]; then
      if [ "${item}" = licenses ]; then
        [ -d "${path}" ] || fail "Expected directory: ${path}"
      else
        [ -f "${path}" ] || fail "Expected regular file: ${path}"
        [ -w "${path}" ] || fail "Server files must be writable, not read-only mounts: ${path}"
      fi
    fi
  done
}

restore_previous() {
  log 'Restoring binaries from the interrupted update; world and auth files are untouched'
  for item in ${items}; do
    target="$(destination "${item}")"
    if [ -e "${transaction}/previous/${item}" ]; then
      if [ "${item}" = licenses ]; then
        rm -rf "${target}" || return 1
        cp -pR "${transaction}/previous/${item}" "${target}" || return 1
      else
        cp -p "${transaction}/previous/${item}" "${target}.restore" || return 1
        mv -f "${target}.restore" "${target}" || return 1
      fi
    elif [ -f "${transaction}/absent-${item}" ]; then
      rm -rf "${target}" || return 1
    fi
  done
  sync -f "${DATA_DIR}" || return 1
  rm -rf "${transaction}" || return 1
}

finish_update() {
  rm -rf "${staging}"
  rm -rf "${backup}"
  mv "${transaction}" "${backup}"
  log "Update installed. Previous binaries retained in ${backup}/previous"
}

check_paths
if [ -d "${transaction}" ]; then
  # Only the fixed managed paths above are ever restored. A prepared transaction
  # has not changed live files yet; an installing transaction must be recovered.
  phase="$(cat "${transaction}/phase" 2>/dev/null || true)"
  case "${phase}" in
    complete) finish_update ;;
    installing) restore_previous ;;
    ''|prepared) rm -rf "${transaction}" ;;
    *) fail "Unknown transaction state; inspect ${transaction} before starting" ;;
  esac
fi
[ -d "${staging}" ] || exit 0
[ -z "$(find "${staging}" ! -type f ! -type d -print -quit)" ] || fail 'Staged updates must contain only regular files and directories'
[ -s "${staging}/Server/HytaleServer.jar" ] || fail 'Staged update has no non-empty Server/HytaleServer.jar; cancel and download it again'
log 'Checking the staged server archive'
unzip -tq "${staging}/Server/HytaleServer.jar" >/dev/null 2>&1 || fail 'Staged server JAR is corrupt; cancel and download it again'
if [ -e "${staging}/Assets.zip" ]; then
  log 'Checking the staged assets archive'
  [ -s "${staging}/Assets.zip" ] && unzip -tq "${staging}/Assets.zip" >/dev/null 2>&1 || fail 'Staged Assets.zip is corrupt'
fi
log 'Preparing the replacement server files'
mkdir -p "${SERVER_DIR}" "${transaction}/previous" "${transaction}/next"
chmod 0700 "${transaction}"
printf 'prepared\n' > "${transaction}/phase"

# Prepare and back up every managed path before replacing any of them.
for item in ${items}; do
  target="$(destination "${item}")"
  if [ -e "${target}" ]; then
    if [ "${item}" = licenses ]; then
      cp -pR "${target}" "${transaction}/previous/${item}"
    else
      ln "${target}" "${transaction}/previous/${item}" 2>/dev/null || cp -p "${target}" "${transaction}/previous/${item}"
    fi
  else
    : > "${transaction}/absent-${item}"
  fi
  source=''
  case "${item}" in
    jar) source="${staging}/Server/HytaleServer.jar" ;;
    assets) source="${staging}/Assets.zip" ;;
    aotconfig) source="${staging}/Server/HytaleServer.aot.config" ;;
    licenses) source="${staging}/Server/Licenses" ;;
    aot) : > "${transaction}/delete-${item}" ;;
  esac
  if [ -n "${source}" ] && [ -e "${source}" ]; then
    if [ "${item}" = licenses ]; then
      [ -d "${source}" ] || fail 'Staged Licenses must be a directory'
      cp -pR "${source}" "${transaction}/next/${item}"
    else
      [ -f "${source}" ] || fail "Expected regular staged file: ${source}"
      cp "${source}" "${transaction}/next/${item}"
      chmod 0644 "${transaction}/next/${item}"
    fi
  elif [ "${item}" = aotconfig ]; then
    : > "${transaction}/delete-${item}"
  fi
done
printf 'installing\n' > "${transaction}/phase.new"
mv "${transaction}/phase.new" "${transaction}/phase"
sync -f "${DATA_DIR}"
on_failure() {
  status=$?
  trap - EXIT
  if [ "${status}" -ne 0 ]; then
    restore_previous || log "Recovery failed; keep ${transaction} for the next startup"
  fi
  exit "${status}"
}
trap on_failure EXIT
for item in ${items}; do
  target="$(destination "${item}")"
  if [ -e "${transaction}/next/${item}" ]; then
    if [ "${item}" = licenses ]; then rm -rf "${target}"; fi
    mv -f "${transaction}/next/${item}" "${target}"
  elif [ -f "${transaction}/delete-${item}" ]; then
    rm -f "${target}"
  fi
done
sync -f "${DATA_DIR}"
printf 'complete\n' > "${transaction}/phase.new"
mv "${transaction}/phase.new" "${transaction}/phase"
sync -f "${DATA_DIR}"
trap - EXIT
finish_update
