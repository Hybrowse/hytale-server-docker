#!/bin/sh
set -eu

usage() {
  cat >&2 <<'EOF'
Usage:
  hytale-cli send <command...>
  hytale-cli send            # read commands from stdin, one per line

Examples:
  hytale-cli send "/auth status"
EOF
}

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

if ! is_true "${HYTALE_CONSOLE_PIPE:-true}"; then
  printf 'ERROR: Console command injection is disabled (HYTALE_CONSOLE_PIPE=false).\n' >&2
  exit 1
fi

FIFO_PATH="${HYTALE_CONSOLE_FIFO:-/tmp/hytale-console.fifo}"

write_to_console() {
  line="$1"

  if [ ! -e "${FIFO_PATH}" ]; then
    printf 'ERROR: Console FIFO does not exist: %s\n' "${FIFO_PATH}" >&2
    printf 'ERROR: Is the server running?\n' >&2
    return 1
  fi

  if [ ! -p "${FIFO_PATH}" ]; then
    printf 'ERROR: Console path exists but is not a FIFO: %s\n' "${FIFO_PATH}" >&2
    return 1
  fi

  if [ ! -w "${FIFO_PATH}" ]; then
    printf 'ERROR: Console FIFO is not writable: %s\n' "${FIFO_PATH}" >&2
    return 1
  fi

  printf '%s\n' "${line}" > "${FIFO_PATH}"
}

cmd="${1:-}"
shift || true

case "${cmd}" in
  send)
    if [ "$#" -gt 0 ]; then
      write_to_console "$*"
      exit 0
    fi

    # Read commands from stdin (one per line)
    while IFS= read -r line; do
      if [ -z "${line}" ]; then
        continue
      fi
      write_to_console "${line}"
    done
    ;;
  -h|--help|help|"" )
    usage
    exit 1
    ;;
  *)
    printf 'ERROR: Unknown command: %s\n' "${cmd}" >&2
    usage
    exit 1
    ;;
esac
