#!/bin/sh
set -eu
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT INT TERM
export SERVER_DIR="${workdir}/server"
mkdir "${SERVER_DIR}"
helper="${ROOT_DIR}/scripts/first-start.sh"
expected="$(printf '%s\n' '/auth persistence Encrypted' '/auth login device')"
[ "$(sh "${helper}" -jar server.jar 2>"${workdir}/guidance")" = "${expected}" ]
grep -q 'name-or-number' "${workdir}/guidance"
[ -z "$(HYTALE_AUTO_AUTH=false sh "${helper}")" ]
[ -z "$(HYTALE_AUTH_MODE=offline sh "${helper}")" ]
[ -z "$(HYTALE_SESSION_TOKEN_BROKER_ENABLED=true sh "${helper}")" ]
[ -z "$(HYTALE_SERVER_SESSION_TOKEN=secret sh "${helper}")" ]
[ -z "$(HYTALE_SERVER_IDENTITY_TOKEN=secret sh "${helper}")" ]
for mode in --help --version --bare --bootstrap --singleplayer --validate-assets --validate-prefabs --validate-world-gen --shutdown-after-validate --verify-worlds --generate-asset-schema --generate-config-schema; do
  [ -z "$(sh "${helper}" "${mode}")" ]
done
printf 'saved-login' > "${SERVER_DIR}/auth.enc"
[ -z "$(sh "${helper}")" ]
[ "$(cat "${SERVER_DIR}/auth.enc")" = saved-login ]

export HYTALE_CONSOLE_FIFO="${workdir}/console"
mkfifo "${HYTALE_CONSOLE_FIFO}"
exec 3<> "${HYTALE_CONSOLE_FIFO}"
cli="${ROOT_DIR}/scripts/hytale-cli.sh"
sh "${cli}" auth login 2>/dev/null
IFS= read -r one <&3
IFS= read -r two <&3
[ "${one}" = '/auth persistence Encrypted' ]
[ "${two}" = '/auth login device' ]
sh "${cli}" auth select ExamplePlayer
IFS= read -r one <&3
[ "${one}" = '/auth select ExamplePlayer' ]
sh "${cli}" auth select 2
IFS= read -r one <&3
[ "${one}" = '/auth select 2' ]
sh "${cli}" auth status
IFS= read -r one <&3
[ "${one}" = '/auth status' ]
if sh "${cli}" auth select "$(printf 'name\n/stop')" 2>/dev/null; then exit 1; fi
if HYTALE_CONSOLE_PIPE=false sh "${cli}" auth login 2>/dev/null; then exit 1; fi
echo 'PASS: first-start login guards, credential reuse and profile commands'
