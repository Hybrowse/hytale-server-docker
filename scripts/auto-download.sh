#!/bin/sh
set -eu

log() {
  printf '%s\n' "$*" >&2
}

lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

is_true() {
  case "$(lower "${1:-}")" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

DATA_DIR="${DATA_DIR:-/data}"
SERVER_DIR="${SERVER_DIR:-/data/server}"

check_dir_writable() {
  dir="$1"
  if [ ! -w "${dir}" ]; then
    log "ERROR: Cannot write to ${dir}"
    log "ERROR: Directory exists but is not writable by UID $(id -u)."
    log "ERROR: Current owner: $(ls -ld "${dir}" 2>/dev/null | awk '{print $3":"$4}')"
    log "ERROR: Fix: 'sudo chown -R $(id -u):$(id -g) <host-path>'"
    log "ERROR: Or delete the directory and let the container recreate it."
    log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/troubleshooting.md"
    exit 1
  fi
}

HYTALE_SERVER_JAR="${HYTALE_SERVER_JAR:-${SERVER_DIR}/HytaleServer.jar}"
HYTALE_ASSETS_PATH="${HYTALE_ASSETS_PATH:-${DATA_DIR}/Assets.zip}"

HYTALE_DOWNLOADER_URL="${HYTALE_DOWNLOADER_URL:-https://downloader.hytale.com/hytale-downloader.zip}"
HYTALE_DOWNLOADER_DIR="${HYTALE_DOWNLOADER_DIR:-${DATA_DIR}/.hytale-downloader}"
HYTALE_GAME_ZIP_PATH="${HYTALE_GAME_ZIP_PATH:-${DATA_DIR}/game.zip}"
HYTALE_DOWNLOADER_PATCHLINE="${HYTALE_DOWNLOADER_PATCHLINE:-}"
HYTALE_DOWNLOADER_SKIP_UPDATE_CHECK="${HYTALE_DOWNLOADER_SKIP_UPDATE_CHECK:-false}"
HYTALE_DOWNLOADER_CREDENTIALS_SRC="${HYTALE_DOWNLOADER_CREDENTIALS_SRC:-}"
HYTALE_DOWNLOADER_RESET_CREDENTIALS="${HYTALE_DOWNLOADER_RESET_CREDENTIALS:-false}"
HYTALE_KEEP_GAME_ZIP="${HYTALE_KEEP_GAME_ZIP:-false}"
HYTALE_DOWNLOAD_LOCK="${HYTALE_DOWNLOAD_LOCK:-true}"
HYTALE_AUTO_UPDATE="${HYTALE_AUTO_UPDATE:-true}"
HYTALE_VERSION_FILE="${HYTALE_VERSION_FILE:-${DATA_DIR}/.hytale-version}"

mkdir -p "${SERVER_DIR}"
check_dir_writable "${SERVER_DIR}"
mkdir -p "${HYTALE_DOWNLOADER_DIR}"
check_dir_writable "${HYTALE_DOWNLOADER_DIR}"

# Lock to avoid multiple containers downloading into the same volume simultaneously.
LOCK_DIR="${DATA_DIR}/.hytale-download-lock"
LOCK_CREATED_AT_PATH="${LOCK_DIR}/created_at_epoch"
LOCK_TTL_SECONDS=300

lock_acquired=0

cleanup() {
  if [ "${lock_acquired}" -eq 1 ]; then
    rm -rf "${LOCK_DIR}" 2>/dev/null || true
  fi
}

if is_true "${HYTALE_DOWNLOAD_LOCK}"; then
  trap cleanup EXIT INT TERM

  for _i in 1 2 3 4 5 6 7 8 9 10; do
    if mkdir "${LOCK_DIR}" 2>/dev/null; then
      lock_acquired=1
      now_epoch="$(date +%s 2>/dev/null || echo 0)"
      printf '%s\n' "${now_epoch}" >"${LOCK_CREATED_AT_PATH}" 2>/dev/null || true
      printf '%s\n' "$$" >"${LOCK_DIR}/pid" 2>/dev/null || true
      break
    fi

    if [ -f "${LOCK_CREATED_AT_PATH}" ]; then
      created_epoch="$(cat "${LOCK_CREATED_AT_PATH}" 2>/dev/null || echo 0)"
      now_epoch="$(date +%s 2>/dev/null || echo 0)"
      if [ "${created_epoch}" -gt 0 ] && [ $((now_epoch - created_epoch)) -ge "${LOCK_TTL_SECONDS}" ]; then
        log "Auto-download: stale lock detected at ${LOCK_DIR} (older than ${LOCK_TTL_SECONDS}s); removing"
        rm -rf "${LOCK_DIR}" 2>/dev/null || true
        continue
      fi
    fi

    log "Auto-download: another container may be downloading into ${DATA_DIR}; waiting for lock (${LOCK_DIR})"
    log "Auto-download: if this gets stuck, delete ${LOCK_DIR} or set HYTALE_DOWNLOAD_LOCK=false (power users)"
    sleep 3
  done

  if [ "${lock_acquired}" -ne 1 ]; then
    log "ERROR: Auto-download: could not acquire lock ${LOCK_DIR}"
    log "ERROR: If no other container is running, the lock may be stale. You can delete ${LOCK_DIR} and try again."
    log "ERROR: Power users can disable the lock with HYTALE_DOWNLOAD_LOCK=false (risk: concurrent downloads may corrupt /data)."
    log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/configuration.md"
    exit 1
  fi
else
  log "Auto-download: download lock disabled via HYTALE_DOWNLOAD_LOCK=false"
fi

server_files_present=0
if [ -f "${HYTALE_SERVER_JAR}" ] && [ -f "${HYTALE_ASSETS_PATH}" ]; then
  server_files_present=1
  if ! is_true "${HYTALE_AUTO_UPDATE}"; then
    log "Auto-download: server files already present and HYTALE_AUTO_UPDATE=false; skipping"
    exit 0
  fi
  log "Auto-download: server files already present; checking for updates"
fi

case "${HYTALE_DOWNLOADER_URL}" in
  https://downloader.hytale.com/*) ;;
  *)
    log "ERROR: HYTALE_DOWNLOADER_URL must start with https://downloader.hytale.com/"
    log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/configuration.md"
    exit 1
    ;;
esac

ZIP_PATH="${HYTALE_DOWNLOADER_DIR}/hytale-downloader.zip"
arch="${HYTALE_TEST_ARCH:-$(uname -m)}"
# The official downloader is x86-64. Only this helper is emulated on ARM64;
# the server JVM continues to use the native architecture.
bin_name="hytale-downloader-linux-amd64"
use_qemu=0
case "${arch}" in
  x86_64|amd64) ;;
  aarch64|arm64)
    if ! command -v qemu-x86_64-static >/dev/null 2>&1; then
      log "ERROR: ARM64 auto-download requires qemu-x86_64-static in the image."
      exit 1
    fi
    use_qemu=1
    log "Auto-download: using x86-64 emulation for the downloader; Java stays native"
    ;;
  *)
    log "ERROR: Unsupported architecture for downloader in container: ${arch}"
    exit 1
    ;;
esac

run_downloader() {
  if [ "${use_qemu}" -eq 1 ]; then
    qemu-x86_64-static "${DOWNLOADER_BIN}" "$@"
  else
    "${DOWNLOADER_BIN}" "$@"
  fi
}

print_game_version() {
  set -- -print-version
  if [ -n "${HYTALE_DOWNLOADER_PATCHLINE}" ]; then
    set -- "$@" -patchline "${HYTALE_DOWNLOADER_PATCHLINE}"
  fi
  if is_true "${HYTALE_DOWNLOADER_SKIP_UPDATE_CHECK}"; then
    set -- "$@" -skip-update-check
  fi
  run_downloader "$@"
}

DOWNLOADER_BIN="${HYTALE_DOWNLOADER_DIR}/hytale-downloader"

if [ ! -x "${DOWNLOADER_BIN}" ]; then
  log "Auto-download: downloading official Hytale Downloader"
  curl -fsSL "${HYTALE_DOWNLOADER_URL}" -o "${ZIP_PATH}"

  if ! unzip -p "${ZIP_PATH}" "${bin_name}" >"${DOWNLOADER_BIN}" 2>/dev/null; then
    log "ERROR: Could not find ${bin_name} in official downloader archive"
    log "ERROR: Ensure HYTALE_DOWNLOADER_URL points to the official downloader archive."
    log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/configuration.md"
    exit 1
  fi

  chmod 0755 "${DOWNLOADER_BIN}"
else
  log "Auto-download: reusing existing downloader binary"
fi

log "Auto-download: first-time auth may require opening a URL and entering a device code (see logs)"

# Persist downloader credentials on the /data volume by running in DATA_DIR.
cd "${DATA_DIR}"

CREDENTIALS_FILE="${DATA_DIR}/.hytale-downloader-credentials.json"

if is_true "${HYTALE_DOWNLOADER_RESET_CREDENTIALS}"; then
  if [ -n "${HYTALE_DOWNLOADER_CREDENTIALS_SRC}" ]; then
    log "ERROR: Cannot reset downloader credentials while HYTALE_DOWNLOADER_CREDENTIALS_SRC is set."
    log "ERROR: Replace the mounted credentials with a fresh login, or unset the source before resetting."
    exit 1
  fi
  log "Auto-download: clearing saved downloader credentials; a new device login is required"
  rm -f "${CREDENTIALS_FILE}"
  log "Auto-download: remove HYTALE_DOWNLOADER_RESET_CREDENTIALS after this login to keep it on the next restart"
fi

if [ -n "${HYTALE_DOWNLOADER_CREDENTIALS_SRC}" ]; then
  if [ ! -f "${HYTALE_DOWNLOADER_CREDENTIALS_SRC}" ]; then
    log "ERROR: HYTALE_DOWNLOADER_CREDENTIALS_SRC is set but file does not exist: ${HYTALE_DOWNLOADER_CREDENTIALS_SRC}"
    log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/configuration.md"
    exit 1
  fi

  log "Auto-download: seeding downloader credentials from mounted file"
  cp -f "${HYTALE_DOWNLOADER_CREDENTIALS_SRC}" "${DATA_DIR}/.hytale-downloader-credentials.json"
fi

if [ "${server_files_present}" -eq 1 ]; then
  if [ ! -f "${CREDENTIALS_FILE}" ]; then
    log "Auto-download: no credentials found; skipping version check (auth required for first download)"
  else
    log "Auto-download: checking remote version"
    remote_version=""
    remote_version="$(print_game_version 2>&1 || true)"

    if [ -n "${remote_version}" ] && ! printf '%s' "${remote_version}" | grep -qi -e "error" -e "failed" -e "authenticate"; then
      local_version=""
      if [ -f "${HYTALE_VERSION_FILE}" ]; then
        local_version="$(cat "${HYTALE_VERSION_FILE}" 2>/dev/null || true)"
      fi

      if [ "${remote_version}" = "${local_version}" ]; then
        log "Auto-download: server is up to date (version: ${local_version})"
        exit 0
      fi
      log "Auto-download: update available (local: ${local_version:-unknown}, remote: ${remote_version})"
    else
      log "Auto-download: could not determine remote version; proceeding with download"
    fi
  fi
fi

log "Auto-download: running downloader"

set -- -download-path "${HYTALE_GAME_ZIP_PATH}"

if [ -n "${HYTALE_DOWNLOADER_PATCHLINE}" ]; then
  set -- "$@" -patchline "${HYTALE_DOWNLOADER_PATCHLINE}"
fi

if is_true "${HYTALE_DOWNLOADER_SKIP_UPDATE_CHECK}"; then
  set -- "$@" -skip-update-check
fi

if run_downloader "$@"; then
  :
else
  status=$?
  log "ERROR: Auto-download failed (exit ${status})."
  log "ERROR: If the downloader reports invalid_grant, its saved login has expired or been revoked."
  if [ -n "${HYTALE_DOWNLOADER_CREDENTIALS_SRC}" ]; then
    log "ERROR: Replace the credentials mounted at HYTALE_DOWNLOADER_CREDENTIALS_SRC with a fresh downloader login."
  else
    log "ERROR: Set HYTALE_DOWNLOADER_RESET_CREDENTIALS=true for one startup and complete the device login in the logs."
  fi
  log "ERROR: HYTALE_SESSION_TOKEN_BROKER_TIMEOUT_SECONDS does not affect downloader authentication."
  log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/troubleshooting.md#expired-downloader-login-invalid_grant"
  exit "${status}"
fi

if [ ! -f "${HYTALE_GAME_ZIP_PATH}" ]; then
  log "ERROR: Auto-download: expected download zip not found: ${HYTALE_GAME_ZIP_PATH}"
  log "ERROR: The downloader may have failed or requires device-code login on first run (see logs above)."
  log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/quickstart.md"
  exit 1
fi

log "Auto-download: extracting Assets.zip and Server/ from game package"

unzip -o "${HYTALE_GAME_ZIP_PATH}" 'Assets.zip' -d "${DATA_DIR}" >/dev/null
tmp_extract_dir="$(mktemp -d /tmp/hytale-server-extract.XXXXXX 2>/dev/null || mktemp -d)"
unzip -o "${HYTALE_GAME_ZIP_PATH}" 'Server/*' -d "${tmp_extract_dir}" >/dev/null

if [ -d "${tmp_extract_dir}/Server" ]; then
  mkdir -p "${SERVER_DIR}"
  if ! cp -r "${tmp_extract_dir}/Server/." "${SERVER_DIR}/"; then
    log "ERROR: Failed to copy server files to ${SERVER_DIR}/"
    log "ERROR: This usually means the directory has wrong permissions."
    log "ERROR: Fix: ensure ${SERVER_DIR} is owned by UID 1000 (e.g., 'sudo chown -R 1000:1000 ${SERVER_DIR}')"
    log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/troubleshooting.md"
    exit 1
  fi
fi

rm -rf "${tmp_extract_dir}" 2>/dev/null || true

if [ ! -f "${HYTALE_ASSETS_PATH}" ]; then
  log "ERROR: Auto-download: Assets.zip not found after extraction at ${HYTALE_ASSETS_PATH}"
  log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/server-files.md"
  exit 1
fi

if [ ! -f "${HYTALE_SERVER_JAR}" ]; then
  log "ERROR: Auto-download: HytaleServer.jar not found after extraction at ${HYTALE_SERVER_JAR}"
  log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/server-files.md"
  exit 1
fi

if ! is_true "${HYTALE_KEEP_GAME_ZIP}"; then
  rm -f "${HYTALE_GAME_ZIP_PATH}" || true
fi

downloaded_version=""
downloaded_version="$(print_game_version 2>/dev/null || true)"
if [ -n "${downloaded_version}" ]; then
  printf '%s\n' "${downloaded_version}" >"${HYTALE_VERSION_FILE}"
  log "Auto-download: saved version ${downloaded_version} to ${HYTALE_VERSION_FILE}"
fi

log "Auto-download: done"
