#!/bin/sh
# Write only console commands to stdout; guidance goes to stderr.
set -eu
is_true() { case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in 1|true|yes|y|on) return 0 ;; *) return 1 ;; esac; }
is_true "${HYTALE_AUTO_AUTH:-true}" || exit 0
[ "$(printf '%s' "${HYTALE_AUTH_MODE:-authenticated}" | tr '[:upper:]' '[:lower:]')" = authenticated ] || exit 0
is_true "${HYTALE_SESSION_TOKEN_BROKER_ENABLED:-false}" && exit 0
[ -z "${HYTALE_SERVER_SESSION_TOKEN:-}" ] && [ -z "${HYTALE_SERVER_IDENTITY_TOKEN:-}" ] || exit 0
[ ! -e "${SERVER_DIR:-/data/server}/auth.enc" ] || exit 0
for arg do
  case "${arg}" in
    --help|--version|--bare|--bootstrap|--singleplayer|--validate-assets|--validate-prefabs|--validate-world-gen|--shutdown-after-validate|--verify-worlds|--generate-asset-schema|--generate-config-schema) exit 0 ;;
  esac
done
printf '%s\n' '/auth persistence Encrypted' '/auth login device'
echo 'First start: opening Hytale device login. Follow the URL and code in the server logs.' >&2
echo 'First start: if several profiles are listed, select one with: hytale-cli auth select <name-or-number>' >&2
echo 'First start: the encrypted login and selected profile are saved on /data for later starts.' >&2
