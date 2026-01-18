#!/bin/sh
set -eu

lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

is_true() {
  case "$(lower "${1:-}")" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

log() {
  printf '%s\n' "$*" >&2
}

DATA_DIR="/data"
SERVER_DIR="/data/server"

check_data_writable() {
  if [ ! -w "${DATA_DIR}" ]; then
    log "ERROR: Cannot write to ${DATA_DIR}"
    log "ERROR: The /data volume must be writable by UID $(id -u)."
    log "ERROR: Fix: 'sudo chown -R $(id -u):$(id -g) <host-path>'"
    log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/troubleshooting.md"
    exit 1
  fi
}

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

check_data_writable

HYTALE_SERVER_JAR="${HYTALE_SERVER_JAR:-${SERVER_DIR}/HytaleServer.jar}"
HYTALE_ASSETS_PATH="${HYTALE_ASSETS_PATH:-${DATA_DIR}/Assets.zip}"
HYTALE_AOT_PATH="${HYTALE_AOT_PATH:-${SERVER_DIR}/HytaleServer.aot}"

HYTALE_BIND="${HYTALE_BIND:-0.0.0.0:5520}"
HYTALE_AUTH_MODE="${HYTALE_AUTH_MODE:-authenticated}"
HYTALE_DISABLE_SENTRY="${HYTALE_DISABLE_SENTRY:-false}"
HYTALE_ACCEPT_EARLY_PLUGINS="${HYTALE_ACCEPT_EARLY_PLUGINS:-false}"

HYTALE_ENABLE_BACKUP="${HYTALE_ENABLE_BACKUP:-false}"
HYTALE_BACKUP_MAX_COUNT="${HYTALE_BACKUP_MAX_COUNT:-}"

HYTALE_ALLOW_OP="${HYTALE_ALLOW_OP:-false}"
HYTALE_BARE="${HYTALE_BARE:-false}"
HYTALE_BOOT_COMMAND="${HYTALE_BOOT_COMMAND:-}"
HYTALE_DISABLE_ASSET_COMPARE="${HYTALE_DISABLE_ASSET_COMPARE:-false}"
HYTALE_DISABLE_CPB_BUILD="${HYTALE_DISABLE_CPB_BUILD:-false}"
HYTALE_DISABLE_FILE_WATCHER="${HYTALE_DISABLE_FILE_WATCHER:-false}"
HYTALE_EARLY_PLUGINS_PATH="${HYTALE_EARLY_PLUGINS_PATH:-}"
HYTALE_EVENT_DEBUG="${HYTALE_EVENT_DEBUG:-false}"
HYTALE_FORCE_NETWORK_FLUSH="${HYTALE_FORCE_NETWORK_FLUSH:-}"
HYTALE_GENERATE_SCHEMA="${HYTALE_GENERATE_SCHEMA:-false}"
HYTALE_LOG="${HYTALE_LOG:-}"
HYTALE_MODS_PATH="${HYTALE_MODS_PATH:-}"
HYTALE_OWNER_NAME="${HYTALE_OWNER_NAME:-}"
HYTALE_OWNER_UUID="${HYTALE_OWNER_UUID:-}"
HYTALE_PREFAB_CACHE_PATH="${HYTALE_PREFAB_CACHE_PATH:-}"
HYTALE_SHUTDOWN_AFTER_VALIDATE="${HYTALE_SHUTDOWN_AFTER_VALIDATE:-false}"
HYTALE_SINGLEPLAYER="${HYTALE_SINGLEPLAYER:-false}"
HYTALE_TRANSPORT="${HYTALE_TRANSPORT:-}"
HYTALE_UNIVERSE_PATH="${HYTALE_UNIVERSE_PATH:-}"
HYTALE_VALIDATE_ASSETS="${HYTALE_VALIDATE_ASSETS:-false}"
HYTALE_VALIDATE_PREFABS="${HYTALE_VALIDATE_PREFABS:-}"
HYTALE_VALIDATE_WORLD_GEN="${HYTALE_VALIDATE_WORLD_GEN:-false}"
HYTALE_WORLD_GEN_PATH="${HYTALE_WORLD_GEN_PATH:-}"

HYTALE_AUTO_DOWNLOAD="${HYTALE_AUTO_DOWNLOAD:-false}"
HYTALE_AUTO_UPDATE="${HYTALE_AUTO_UPDATE:-true}"

HYTALE_CONSOLE_PIPE="${HYTALE_CONSOLE_PIPE:-true}"

HYTALE_CURSEFORGE_MODS="${HYTALE_CURSEFORGE_MODS:-}"

ENABLE_AOT="${ENABLE_AOT:-auto}"

HYTALE_MACHINE_ID="${HYTALE_MACHINE_ID:-}"

user_args="$*"

mkdir -p "${SERVER_DIR}"
check_dir_writable "${SERVER_DIR}"

setup_machine_id() {
  MACHINE_ID_FILE="/etc/machine-id"
  MACHINE_ID_PERSISTENT="${DATA_DIR}/.machine-id"

  if [ -n "${HYTALE_MACHINE_ID}" ]; then
    machine_id="${HYTALE_MACHINE_ID}"
  elif [ -f "${MACHINE_ID_PERSISTENT}" ]; then
    machine_id="$(cat "${MACHINE_ID_PERSISTENT}" 2>/dev/null || true)"
  else
    machine_id=""
  fi

  if [ -z "${machine_id}" ] || [ "${#machine_id}" -ne 32 ]; then
    if command -v uuidgen >/dev/null 2>&1; then
      machine_id="$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')"
    else
      machine_id="$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | tr '[:upper:]' '[:lower:]' || true)"
    fi
  fi

  if [ -z "${machine_id}" ] || [ "${#machine_id}" -ne 32 ]; then
    log "ERROR: Failed to generate a valid machine-id"
    exit 1
  fi

  if ! ( printf '%s\n' "${machine_id}" > "${MACHINE_ID_FILE}" ) 2>/dev/null; then
    log "WARNING: Could not write to ${MACHINE_ID_FILE} (read-only filesystem?)"
    log "WARNING: The Hytale server may fail with 'Failed to get Hardware UUID'."
    log "WARNING: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/troubleshooting.md"
  fi
  printf '%s\n' "${machine_id}" > "${MACHINE_ID_PERSISTENT}" 2>/dev/null || true
}

setup_machine_id

log "Thank you for using the Hytale Server Docker Image by Hybrowse!"
log "- Add your server to our server list: https://hybrowse.gg"
log "- GitHub: https://github.com/Hybrowse/hytale-server-docker"
log "- Console: 'docker compose attach hytale' (detach: Ctrl-p then Ctrl-q)"
log ""

if is_true "${HYTALE_AUTO_DOWNLOAD}"; then
  log "Auto-download: enabled (first run may require opening an auth URL from the logs)"
fi

missing=0
if [ ! -f "${HYTALE_SERVER_JAR}" ]; then
  if is_true "${HYTALE_AUTO_DOWNLOAD}"; then
    log "Missing server jar: ${HYTALE_SERVER_JAR}"
  else
    log "ERROR: Missing server jar: ${HYTALE_SERVER_JAR}"
  fi
  missing=1
fi
if [ ! -f "${HYTALE_ASSETS_PATH}" ]; then
  if is_true "${HYTALE_AUTO_DOWNLOAD}"; then
    log "Missing assets: ${HYTALE_ASSETS_PATH}"
  else
    log "ERROR: Missing assets: ${HYTALE_ASSETS_PATH}"
  fi
  missing=1
fi

if is_true "${HYTALE_AUTO_DOWNLOAD}"; then
  if [ "${missing}" -ne 0 ]; then
    log "Attempting auto-download via official Hytale Downloader"
    /usr/local/bin/hytale-auto-download

    missing=0
    if [ ! -f "${HYTALE_SERVER_JAR}" ]; then
      log "ERROR: Missing server jar: ${HYTALE_SERVER_JAR}"
      missing=1
    fi
    if [ ! -f "${HYTALE_ASSETS_PATH}" ]; then
      log "ERROR: Missing assets: ${HYTALE_ASSETS_PATH}"
      missing=1
    fi
  else
    if is_true "${HYTALE_AUTO_UPDATE}"; then
      log "Attempting auto-download via official Hytale Downloader"
      /usr/local/bin/hytale-auto-download
    fi
  fi
fi

if [ "${missing}" -ne 0 ]; then
  log ""
  log "Expected volume layout:"
  log "  ${DATA_DIR}/Assets.zip"
  log "  ${SERVER_DIR}/HytaleServer.jar"
  log ""
  log "How to fix:"
  log "- Place the official server files into ${SERVER_DIR}/"
  log "- Place Assets.zip into ${DATA_DIR}/Assets.zip"
  log "- Or set HYTALE_AUTO_DOWNLOAD=true"
  log "- On Apple Silicon (arm64): auto-download requires running the container as linux/amd64 (Docker Compose: platform: linux/amd64)"
  log "- See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/server-files.md"
  log "- See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/quickstart.md"
  exit 1
fi

if [ -n "${HYTALE_CURSEFORGE_MODS}" ]; then
  if [ -z "${HYTALE_MODS_PATH:-}" ]; then
    HYTALE_MODS_PATH="${DATA_DIR}/server/mods-curseforge"
  fi
  mkdir -p "${HYTALE_MODS_PATH}"
  check_dir_writable "${HYTALE_MODS_PATH}"
  /usr/local/bin/hytale-curseforge-mods
fi

log "Starting Hytale dedicated server"
log "- Assets: ${HYTALE_ASSETS_PATH}"
log "- Bind: ${HYTALE_BIND}"
log "- Auth mode: ${HYTALE_AUTH_MODE}"

if is_true "${HYTALE_DISABLE_SENTRY}"; then
  log "- Disable Sentry: enabled"
fi

if is_true "${HYTALE_ACCEPT_EARLY_PLUGINS}"; then
  log "- Accept early plugins: enabled"
fi

if is_true "${HYTALE_ENABLE_BACKUP}"; then
  if [ -z "${HYTALE_BACKUP_DIR:-}" ]; then
    HYTALE_BACKUP_DIR="${DATA_DIR}/backups"
  fi
  mkdir -p "${HYTALE_BACKUP_DIR}"
  log "- Backup: enabled"
  log "- Backup dir: ${HYTALE_BACKUP_DIR}"
fi

if [ -n "${JVM_XMS:-}" ]; then
  log "- JVM_XMS: ${JVM_XMS}"
fi

if [ -n "${JVM_XMX:-}" ]; then
  log "- JVM_XMX: ${JVM_XMX}"
fi

if [ -n "${HYTALE_SERVER_SESSION_TOKEN:-}" ]; then
  log "- Session token: [set]"
fi

if [ -n "${HYTALE_SERVER_IDENTITY_TOKEN:-}" ]; then
  log "- Identity token: [set]"
fi

set -- java

if [ -n "${JVM_XMS:-}" ]; then
  set -- "$@" "-Xms${JVM_XMS}"
fi

if [ -n "${JVM_XMX:-}" ]; then
  set -- "$@" "-Xmx${JVM_XMX}"
fi

aot_generate=0

case "$(lower "${ENABLE_AOT}")" in
  generate|create)
    set -- "$@" "-XX:AOTCacheOutput=${HYTALE_AOT_PATH}"
    log "- AOT: generating cache"
    aot_generate=1
    ;;
  auto|"")
    if [ -f "${HYTALE_AOT_PATH}" ]; then
      set -- "$@" "-XX:AOTCache=${HYTALE_AOT_PATH}" "-XX:AOTMode=auto"
      log "- AOT: enabled (auto)"
    else
      log "- AOT: disabled (auto, cache missing)"
    fi
    ;;
  true|1|yes|on)
    if [ -f "${HYTALE_AOT_PATH}" ]; then
      set -- "$@" "-XX:AOTCache=${HYTALE_AOT_PATH}" "-XX:AOTMode=on"
      log "- AOT: enabled"
    else
      log "ERROR: ENABLE_AOT=true but AOT cache file does not exist: ${HYTALE_AOT_PATH}"
      log "ERROR: Generate an AOT cache (ENABLE_AOT=generate) or disable AOT (ENABLE_AOT=false)."
      log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/configuration.md"
      exit 1
    fi
    ;;
  false|0|no|off)
    log "- AOT: disabled"
    ;;
  *)
    log "ERROR: Invalid ENABLE_AOT value: ${ENABLE_AOT} (expected: auto|true|false|generate)"
    log "ERROR: See https://github.com/Hybrowse/hytale-server-docker/blob/main/docs/image/configuration.md"
    exit 1
    ;;
esac

if [ -n "${JVM_EXTRA_ARGS:-}" ]; then
  set -- "$@" ${JVM_EXTRA_ARGS}
fi

set -- "$@" -jar "${HYTALE_SERVER_JAR}" --assets "${HYTALE_ASSETS_PATH}"

if [ -n "${HYTALE_BIND}" ]; then
  set -- "$@" --bind "${HYTALE_BIND}"
fi

if [ -n "${HYTALE_AUTH_MODE}" ]; then
  set -- "$@" --auth-mode "${HYTALE_AUTH_MODE}"
fi

if is_true "${HYTALE_DISABLE_SENTRY}"; then
  set -- "$@" --disable-sentry
fi

if is_true "${HYTALE_ACCEPT_EARLY_PLUGINS}"; then
  set -- "$@" --accept-early-plugins
fi

if is_true "${HYTALE_ENABLE_BACKUP}"; then
  set -- "$@" --backup
fi

if [ -n "${HYTALE_BACKUP_DIR:-}" ]; then
  set -- "$@" --backup-dir "${HYTALE_BACKUP_DIR}"
fi

if [ -n "${HYTALE_BACKUP_FREQUENCY_MINUTES:-}" ]; then
  set -- "$@" --backup-frequency "${HYTALE_BACKUP_FREQUENCY_MINUTES}"
fi

if [ -n "${HYTALE_BACKUP_MAX_COUNT:-}" ]; then
  set -- "$@" --backup-max-count "${HYTALE_BACKUP_MAX_COUNT}"
fi

if is_true "${HYTALE_ALLOW_OP}"; then
  set -- "$@" --allow-op
fi

if is_true "${HYTALE_BARE}"; then
  set -- "$@" --bare
fi

if [ -n "${HYTALE_BOOT_COMMAND:-}" ]; then
  set -- "$@" --boot-command "${HYTALE_BOOT_COMMAND}"
fi

if is_true "${HYTALE_DISABLE_ASSET_COMPARE}"; then
  set -- "$@" --disable-asset-compare
fi

if is_true "${HYTALE_DISABLE_CPB_BUILD}"; then
  set -- "$@" --disable-cpb-build
fi

if is_true "${HYTALE_DISABLE_FILE_WATCHER}"; then
  set -- "$@" --disable-file-watcher
fi

if [ -n "${HYTALE_EARLY_PLUGINS_PATH:-}" ]; then
  set -- "$@" --early-plugins "${HYTALE_EARLY_PLUGINS_PATH}"
fi

if is_true "${HYTALE_EVENT_DEBUG}"; then
  set -- "$@" --event-debug
fi

if [ -n "${HYTALE_FORCE_NETWORK_FLUSH:-}" ]; then
  set -- "$@" --force-network-flush "${HYTALE_FORCE_NETWORK_FLUSH}"
fi

if is_true "${HYTALE_GENERATE_SCHEMA}"; then
  set -- "$@" --generate-schema
fi

if [ -n "${HYTALE_LOG:-}" ]; then
  set -- "$@" --log "${HYTALE_LOG}"
fi

if [ -n "${HYTALE_MODS_PATH:-}" ]; then
  set -- "$@" --mods "${HYTALE_MODS_PATH}"
fi

if [ -n "${HYTALE_OWNER_NAME:-}" ]; then
  set -- "$@" --owner-name "${HYTALE_OWNER_NAME}"
fi

if [ -n "${HYTALE_OWNER_UUID:-}" ]; then
  set -- "$@" --owner-uuid "${HYTALE_OWNER_UUID}"
fi

if [ -n "${HYTALE_PREFAB_CACHE_PATH:-}" ]; then
  set -- "$@" --prefab-cache "${HYTALE_PREFAB_CACHE_PATH}"
fi

if is_true "${HYTALE_SHUTDOWN_AFTER_VALIDATE}"; then
  set -- "$@" --shutdown-after-validate
fi

if is_true "${HYTALE_SINGLEPLAYER}"; then
  set -- "$@" --singleplayer
fi

if [ -n "${HYTALE_TRANSPORT:-}" ]; then
  set -- "$@" --transport "${HYTALE_TRANSPORT}"
fi

if [ -n "${HYTALE_UNIVERSE_PATH:-}" ]; then
  set -- "$@" --universe "${HYTALE_UNIVERSE_PATH}"
fi

if is_true "${HYTALE_VALIDATE_ASSETS}"; then
  set -- "$@" --validate-assets
fi

if [ -n "${HYTALE_VALIDATE_PREFABS:-}" ]; then
  if is_true "${HYTALE_VALIDATE_PREFABS}"; then
    set -- "$@" --validate-prefabs
  else
    set -- "$@" --validate-prefabs "${HYTALE_VALIDATE_PREFABS}"
  fi
fi

if is_true "${HYTALE_VALIDATE_WORLD_GEN}"; then
  set -- "$@" --validate-world-gen
fi

if [ -n "${HYTALE_WORLD_GEN_PATH:-}" ]; then
  set -- "$@" --world-gen "${HYTALE_WORLD_GEN_PATH}"
fi

if [ "${aot_generate}" -eq 1 ]; then
  set -- "$@" --bare --validate-assets --shutdown-after-validate
fi

if [ -n "${EXTRA_SERVER_ARGS:-}" ]; then
  set -- "$@" ${EXTRA_SERVER_ARGS}
fi

if [ -n "${user_args}" ]; then
  set -- "$@" ${user_args}
fi

if [ -n "${HYTALE_SERVER_SESSION_TOKEN:-}" ]; then
  set -- "$@" --session-token "${HYTALE_SERVER_SESSION_TOKEN}"
fi

if [ -n "${HYTALE_SERVER_IDENTITY_TOKEN:-}" ]; then
  set -- "$@" --identity-token "${HYTALE_SERVER_IDENTITY_TOKEN}"
fi

if is_true "${HYTALE_CONSOLE_PIPE}"; then
  CONSOLE_FIFO="${HYTALE_CONSOLE_FIFO:-/tmp/hytale-console.fifo}"

  if [ -e "${CONSOLE_FIFO}" ] && [ ! -p "${CONSOLE_FIFO}" ]; then
    rm -f "${CONSOLE_FIFO}" 2>/dev/null || true
  fi

  if [ ! -p "${CONSOLE_FIFO}" ]; then
    rm -f "${CONSOLE_FIFO}" 2>/dev/null || true
    mkfifo "${CONSOLE_FIFO}"
    chown hytale "${CONSOLE_FIFO}" 2>/dev/null || true
    chmod 0600 "${CONSOLE_FIFO}" 2>/dev/null || true
  fi

  exec 3<> "${CONSOLE_FIFO}"
  cd "${SERVER_DIR}"
  exec "$@" <&3
fi

cd "${SERVER_DIR}"
exec "$@"
