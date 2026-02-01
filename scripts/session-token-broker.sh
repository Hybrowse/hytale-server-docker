#!/bin/sh

hytale_token_broker_lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

hytale_token_broker_is_true() {
  case "$(hytale_token_broker_lower "${1:-}")" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

hytale_token_broker_log() {
  printf '%s\n' "$*" >&2
}

hytale_token_broker_fetch() {
  if [ -n "${HYTALE_SERVER_SESSION_TOKEN:-}" ] && [ -n "${HYTALE_SERVER_IDENTITY_TOKEN:-}" ]; then
    hytale_token_broker_log "Token broker: skipping (HYTALE_SERVER_SESSION_TOKEN and HYTALE_SERVER_IDENTITY_TOKEN already set)"
    return 0
  fi

  if [ -n "${HYTALE_SESSION_TOKEN_BROKER_MIN_RETRY_INTERVAL_SECONDS:-}" ]; then
    now="$(date +%s 2>/dev/null || true)"
    data_dir="${DATA_DIR:-/data}"
    state_file="${data_dir}/.hytale-session-token-broker-last-fetch"
    min_interval="${HYTALE_SESSION_TOKEN_BROKER_MIN_RETRY_INTERVAL_SECONDS}"

    case "${now}" in
      ''|*[!0-9]*) now="" ;;
    esac
    case "${min_interval}" in
      ''|*[!0-9]*) min_interval="" ;;
    esac

    if [ -n "${now}" ] && [ -n "${min_interval}" ] && [ "${min_interval}" -gt 0 ] && [ -f "${state_file}" ]; then
      last="$(cat "${state_file}" 2>/dev/null || true)"
      case "${last}" in
        ''|*[!0-9]*) last="" ;;
      esac

      if [ -n "${last}" ] && [ "${now}" -ge "${last}" ]; then
        elapsed="$((now - last))"
        if [ "${elapsed}" -lt "${min_interval}" ]; then
          wait="$((min_interval - elapsed))"
          hytale_token_broker_log "Token broker: last fetch was ${elapsed}s ago, waiting ${wait}s before minting again"
          sleep "${wait}" 2>/dev/null || true
        fi
      fi
    fi
  fi

  if [ -z "${HYTALE_SESSION_TOKEN_BROKER_URL:-}" ]; then
    hytale_token_broker_log "ERROR: HYTALE_SESSION_TOKEN_BROKER_ENABLED=true but HYTALE_SESSION_TOKEN_BROKER_URL is empty"
    exit 1
  fi

  broker_url="${HYTALE_SESSION_TOKEN_BROKER_URL%/}"
  endpoint="${broker_url}/v1/game-session"

  if [ -z "${HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN:-}" ] && [ -n "${HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC:-}" ]; then
    if [ ! -f "${HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC}" ]; then
      hytale_token_broker_log "ERROR: HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC does not exist: ${HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC}"
      exit 1
    fi
    HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN="$(cat "${HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC}" 2>/dev/null | tr -d '\r\n' || true)"
    if [ -z "${HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN:-}" ]; then
      hytale_token_broker_log "ERROR: HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC did not contain a token"
      exit 1
    fi
  fi

  profiles_json="[]"
  if [ -n "${HYTALE_SESSION_TOKEN_BROKER_PROFILE_UUIDS:-}" ]; then
    profiles_json="$(printf '%s' "${HYTALE_SESSION_TOKEN_BROKER_PROFILE_UUIDS}" \
      | tr ',\t ' '\n' \
      | jq -R -s -c 'split("\n") | map(select(length>0))' 2>/dev/null || true)"
  fi

  body="$(jq -cn \
    --arg account "${HYTALE_SESSION_TOKEN_BROKER_ACCOUNT:-}" \
    --argjson profiles "${profiles_json}" \
    '({} | (if $account != "" then . + {account: $account} else . end) | (if ($profiles|length) > 0 then . + {profile_uuids: $profiles} else . end))' \
    2>/dev/null || true)"

  if [ -z "${body}" ]; then
    hytale_token_broker_log "ERROR: Failed to build token broker request body"
    exit 1
  fi

  headers_file=""
  resp_file=""

  hytale_token_broker_cleanup() {
    if [ -n "${headers_file}" ]; then
      rm -f "${headers_file}" 2>/dev/null || true
    fi
    if [ -n "${resp_file}" ]; then
      rm -f "${resp_file}" 2>/dev/null || true
    fi
  }

  headers_file="$(mktemp 2>/dev/null || true)"
  resp_file="$(mktemp 2>/dev/null || true)"
  if [ -z "${headers_file}" ] || [ -z "${resp_file}" ]; then
    hytale_token_broker_cleanup
    hytale_token_broker_log "ERROR: Failed to create temporary files for token broker response"
    exit 1
  fi

  if [ -n "${HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN:-}" ]; then
    http_code="$(
      curl -sS -X POST \
        --max-time "${HYTALE_SESSION_TOKEN_BROKER_TIMEOUT_SECONDS}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN}" \
        -D "${headers_file}" \
        -o "${resp_file}" \
        -w '%{http_code}' \
        "${endpoint}" \
        -d "${body}" \
        2>/dev/null || true
    )"
  else
    http_code="$(
      curl -sS -X POST \
        --max-time "${HYTALE_SESSION_TOKEN_BROKER_TIMEOUT_SECONDS}" \
        -H "Content-Type: application/json" \
        -D "${headers_file}" \
        -o "${resp_file}" \
        -w '%{http_code}' \
        "${endpoint}" \
        -d "${body}" \
        2>/dev/null || true
    )"
  fi

  if [ "${http_code}" != "200" ]; then
    broker_err="$(jq -r '.error? // empty' "${resp_file}" 2>/dev/null || true)"
    if [ -n "${broker_err}" ]; then
      hytale_token_broker_log "ERROR: Token broker request failed: ${broker_err}"
    else
      hytale_token_broker_log "ERROR: Token broker request failed (HTTP ${http_code})"
    fi

    if hytale_token_broker_is_true "${HYTALE_SESSION_TOKEN_BROKER_FAIL_ON_ERROR}"; then
      hytale_token_broker_cleanup
      exit 1
    fi

    hytale_token_broker_log "WARNING: Continuing without token broker tokens"
    hytale_token_broker_cleanup
    return 0
  fi

  session_token="$(jq -r '.session_token // empty' "${resp_file}" 2>/dev/null || true)"
  identity_token="$(jq -r '.identity_token // empty' "${resp_file}" 2>/dev/null || true)"

  if [ -z "${session_token}" ] || [ -z "${identity_token}" ]; then
    hytale_token_broker_log "ERROR: Token broker response did not include session_token and identity_token"
    if hytale_token_broker_is_true "${HYTALE_SESSION_TOKEN_BROKER_FAIL_ON_ERROR}"; then
      hytale_token_broker_cleanup
      exit 1
    fi
    hytale_token_broker_log "WARNING: Continuing without token broker tokens"
    hytale_token_broker_cleanup
    return 0
  fi

  export HYTALE_SERVER_SESSION_TOKEN="${session_token}"
  export HYTALE_SERVER_IDENTITY_TOKEN="${identity_token}"

  if [ -n "${HYTALE_SESSION_TOKEN_BROKER_MIN_RETRY_INTERVAL_SECONDS:-}" ]; then
    now="$(date +%s 2>/dev/null || true)"
    data_dir="${DATA_DIR:-/data}"
    state_file="${data_dir}/.hytale-session-token-broker-last-fetch"
    case "${now}" in
      ''|*[!0-9]*) now="" ;;
    esac
    if [ -n "${now}" ]; then
      if printf '%s\n' "${now}" >"${state_file}" 2>/dev/null; then
        chmod 0600 "${state_file}" 2>/dev/null || true
      fi
    fi
  fi

  hytale_token_broker_cleanup
  hytale_token_broker_log "Token broker: fetched server session/identity tokens"
}
