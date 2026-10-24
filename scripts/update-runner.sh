#!/bin/sh
set -eu
log() { printf '%s\n' "Update runner: $*" >&2; }
fail() { log "ERROR: $*"; exit 1; }
is_true() { case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in 1|true|yes|y|on) return 0 ;; *) return 1 ;; esac; }

[ "${HYTALE_SERVER_JAR:-/data/server/HytaleServer.jar}" = /data/server/HytaleServer.jar ] || fail 'Native updates require the standard server JAR path'
[ "${HYTALE_AOT_PATH:-/data/server/HytaleServer.aot}" = /data/server/HytaleServer.aot ] || fail 'Native updates require the standard AOT cache path'
[ "${HYTALE_ASSETS_PATH:-/data/Assets.zip}" = /data/Assets.zip ] || fail 'Native updates require the standard assets path'
if is_true "${HYTALE_AUTO_DOWNLOAD:-false}" && is_true "${HYTALE_AUTO_UPDATE:-true}"; then
  fail 'Set HYTALE_AUTO_UPDATE=false when HYTALE_NATIVE_UPDATES=true; choose one update mechanism'
fi
if is_true "${HYTALE_DISABLE_UPDATES:-false}"; then
  fail 'HYTALE_DISABLE_UPDATES=true conflicts with HYTALE_NATIVE_UPDATES=true'
fi
[ ! -L /data/updater ] || fail 'Refusing a symbolic link at /data/updater'
mkdir -p /data/updater
[ ! -L /data/updater/image-runner.lock ] || fail 'Refusing a symbolic update lock'
exec 9>/data/updater/image-runner.lock
flock -n 9 || fail 'Another native-update runner is already using this data volume'
[ ! -L /data/start.sh ] || fail 'Refusing a symbolic link at /data/start.sh'
if [ ! -e /data/start.sh ]; then
  # The official updater checks for a launcher in the parent directory. This
  # container-owned launcher keeps the image configuration when used in Docker.
  printf '#!/bin/sh\nexec /usr/local/bin/hytale-entrypoint "$@"\n' > /data/start.sh
  chmod 0755 /data/start.sh
fi
export HYTALE_DISABLE_UPDATES=false
export _HYTALE_UPDATE_CHILD=true
child=''
stopping=0
stop_child() {
  stopping=1
  [ -z "${child}" ] || kill -TERM "${child}" 2>/dev/null || true
}
trap stop_child TERM INT
while :; do
  /usr/local/bin/hytale-apply-update
  [ "${stopping}" -eq 0 ] || exit 143
  /usr/local/bin/hytale-entrypoint "$@" <&0 &
  child=$!
  status=0
  wait "${child}" || status=$?
  if [ "${stopping}" -ne 0 ]; then
    # wait can be interrupted by the trap before Java finishes saving its world.
    wait "${child}" 2>/dev/null || true
    exit 143
  fi
  child=''
  [ "${status}" -eq 8 ] || exit "${status}"
  [ -d /data/updater/staging ] || fail 'Server requested an update restart but no staged update exists'
  log 'Server stopped for an update; applying staged files before restarting'
done
