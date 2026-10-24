#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT INT TERM
mkdir -p "${workdir}/package/Server" "${workdir}/data/.hytale-downloader"
printf 'assets' > "${workdir}/package/Assets.zip"
printf 'server' > "${workdir}/package/Server/HytaleServer.jar"
(cd "${workdir}/package" && zip -qr "${workdir}/game.zip" .)

cat > "${workdir}/data/.hytale-downloader/hytale-downloader" <<'DOWNLOADER'
#!/bin/sh
set -eu
if [ "${1}" = "-print-version" ]; then
  echo 'test-version'
  exit 0
fi
if [ -f .hytale-downloader-credentials.json ]; then
  echo 'oauth2: "invalid_grant"' >&2
  exit 7
fi
echo 'DEVICE LOGIN (test stub)'
printf 'fresh-login' > .hytale-downloader-credentials.json
cp "${TEST_GAME_ZIP}" "$2"
DOWNLOADER
chmod +x "${workdir}/data/.hytale-downloader/hytale-downloader"

export DATA_DIR="${workdir}/data"
export SERVER_DIR="${DATA_DIR}/server"
export HYTALE_TEST_ARCH=amd64
export TEST_GAME_ZIP="${workdir}/game.zip"
printf 'expired-login' > "${DATA_DIR}/.hytale-downloader-credentials.json"
printf 'server-login' > "${DATA_DIR}/auth.enc"
printf 'world-data' > "${DATA_DIR}/world-marker"

status=0
sh "${ROOT_DIR}/scripts/auto-download.sh" > "${workdir}/out" 2>&1 || status=$?
[ "${status}" -eq 7 ]
grep -q 'HYTALE_DOWNLOADER_RESET_CREDENTIALS=true' "${workdir}/out"
[ "$(cat "${DATA_DIR}/.hytale-downloader-credentials.json")" = 'expired-login' ]

HYTALE_DOWNLOADER_RESET_CREDENTIALS=true sh "${ROOT_DIR}/scripts/auto-download.sh" > "${workdir}/out" 2>&1
grep -q 'DEVICE LOGIN' "${workdir}/out"
[ "$(cat "${DATA_DIR}/.hytale-downloader-credentials.json")" = 'fresh-login' ]
[ "$(cat "${SERVER_DIR}/HytaleServer.jar")" = 'server' ]
[ "$(cat "${DATA_DIR}/Assets.zip")" = 'assets' ]
[ "$(cat "${DATA_DIR}/auth.enc")" = 'server-login' ]
[ "$(cat "${DATA_DIR}/world-marker")" = 'world-data' ]

# Mounted secrets must not silently reintroduce the expired login.
printf 'mounted-login' > "${workdir}/mounted-credentials"
status=0
HYTALE_DOWNLOADER_RESET_CREDENTIALS=true \
  HYTALE_DOWNLOADER_CREDENTIALS_SRC="${workdir}/mounted-credentials" \
  sh "${ROOT_DIR}/scripts/auto-download.sh" > "${workdir}/out" 2>&1 || status=$?
[ "${status}" -ne 0 ]
grep -q 'Cannot reset downloader credentials' "${workdir}/out"
[ "$(cat "${DATA_DIR}/.hytale-downloader-credentials.json")" = 'fresh-login' ]
[ "$(cat "${workdir}/mounted-credentials")" = 'mounted-login' ]

rm -f "${DATA_DIR}/.hytale-version"
status=0
HYTALE_DOWNLOADER_CREDENTIALS_SRC="${workdir}/mounted-credentials" \
  sh "${ROOT_DIR}/scripts/auto-download.sh" > "${workdir}/out" 2>&1 || status=$?
[ "${status}" -eq 7 ]
grep -q 'Replace the credentials mounted' "${workdir}/out"
[ "$(cat "${workdir}/mounted-credentials")" = 'mounted-login' ]
printf '%s\n' 'PASS: downloader login recovery (no network)'
