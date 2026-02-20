#!/bin/sh
set -eu

log() {
  printf '%s\n' "$*" >&2
}

debug_enabled=0
debug() {
  if [ "${debug_enabled}" -eq 1 ]; then
    log "CurseForge mods: DEBUG: $*"
  fi
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

trim() {
  s="${1:-}"
  s="$(printf '%s' "${s}" | sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//')"
  printf '%s' "${s}"
}

expand_refs() {
  input="$1"
  printf '%s\n' "${input}" | while IFS= read -r raw_line || [ -n "${raw_line}" ]; do
    raw_line="$(printf '%s' "${raw_line}" | sed 's/#.*$//')"
    raw_line="$(trim "${raw_line}")"
    if [ -z "${raw_line}" ]; then
      continue
    fi

    for token in ${raw_line}; do
      case "${token}" in
        @*)
          path="${token#@}"
          if [ -f "${path}" ]; then
            while IFS= read -r line || [ -n "${line}" ]; do
              line="$(printf '%s' "${line}" | sed 's/#.*$//')"
              line="$(trim "${line}")"
              if [ -z "${line}" ]; then
                continue
              fi
              for t in ${line}; do
                printf '%s\n' "${t}"
              done
            done <"${path}"
          else
            log "WARNING: listing file not found: ${path}"
          fi
          ;;
        *)
          printf '%s\n' "${token}"
          ;;
      esac
    done
  done
}

DATA_DIR="${DATA_DIR:-/data}"
CF_API_BASE="https://api.curseforge.com"
CF_API_HOST="api.curseforge.com"

HYTALE_CURSEFORGE_HTTP_CACHE_URL="${HYTALE_CURSEFORGE_HTTP_CACHE_URL:-}"
HYTALE_CURSEFORGE_HTTP_CACHE_API_URL="${HYTALE_CURSEFORGE_HTTP_CACHE_API_URL:-${HYTALE_CURSEFORGE_HTTP_CACHE_URL}}"
HYTALE_CURSEFORGE_HTTP_CACHE_DOWNLOAD_URL="${HYTALE_CURSEFORGE_HTTP_CACHE_DOWNLOAD_URL:-${HYTALE_CURSEFORGE_HTTP_CACHE_URL}}"

HYTALE_MODS_PATH="${HYTALE_MODS_PATH:-}"

HYTALE_CURSEFORGE_MODS="${HYTALE_CURSEFORGE_MODS:-}"
HYTALE_CURSEFORGE_API_KEY="${HYTALE_CURSEFORGE_API_KEY:-}"
HYTALE_CURSEFORGE_API_KEY_SRC="${HYTALE_CURSEFORGE_API_KEY_SRC:-}"
HYTALE_CURSEFORGE_AUTO_UPDATE="${HYTALE_CURSEFORGE_AUTO_UPDATE:-true}"
HYTALE_CURSEFORGE_RELEASE_CHANNEL="${HYTALE_CURSEFORGE_RELEASE_CHANNEL:-release}"
HYTALE_CURSEFORGE_FAIL_ON_ERROR="${HYTALE_CURSEFORGE_FAIL_ON_ERROR:-false}"
HYTALE_CURSEFORGE_CHECK_INTERVAL_SECONDS="${HYTALE_CURSEFORGE_CHECK_INTERVAL_SECONDS:-0}"
HYTALE_CURSEFORGE_GAME_VERSION_FILTER="${HYTALE_CURSEFORGE_GAME_VERSION_FILTER:-}"
HYTALE_CURSEFORGE_LOCK="${HYTALE_CURSEFORGE_LOCK:-true}"
HYTALE_CURSEFORGE_EXPAND_REFS_ONLY="${HYTALE_CURSEFORGE_EXPAND_REFS_ONLY:-false}"
HYTALE_CURSEFORGE_DEBUG="${HYTALE_CURSEFORGE_DEBUG:-false}"

if is_true "${HYTALE_CURSEFORGE_DEBUG}"; then
  debug_enabled=1
fi

if is_true "${HYTALE_CURSEFORGE_EXPAND_REFS_ONLY}"; then
  expand_refs "${HYTALE_CURSEFORGE_MODS}"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  log "ERROR: CurseForge mods: jq is required but was not found"
  exit 1
fi

case "${HYTALE_CURSEFORGE_CHECK_INTERVAL_SECONDS}" in
  ''|*[!0-9]*)
    log "ERROR: Invalid HYTALE_CURSEFORGE_CHECK_INTERVAL_SECONDS value: ${HYTALE_CURSEFORGE_CHECK_INTERVAL_SECONDS} (expected integer seconds)"
    exit 1
    ;;
esac

if [ -z "${HYTALE_CURSEFORGE_MODS}" ]; then
  exit 0
fi

CF_STANDARD_MODS_DIR="${DATA_DIR}/server/mods"
CF_MODS_DIR="${HYTALE_MODS_PATH:-${DATA_DIR}/server/mods-curseforge}"

if [ -z "${HYTALE_CURSEFORGE_PRUNE+x}" ]; then
  mods_path_for_compare="${CF_MODS_DIR%/}"
  standard_mods_path_for_compare="${CF_STANDARD_MODS_DIR%/}"
  if [ "${mods_path_for_compare}" = "${standard_mods_path_for_compare}" ]; then
    HYTALE_CURSEFORGE_PRUNE="false"
  else
    HYTALE_CURSEFORGE_PRUNE="true"
  fi
  debug "HYTALE_CURSEFORGE_PRUNE not set; defaulting to ${HYTALE_CURSEFORGE_PRUNE} (mods path: ${CF_MODS_DIR})"
fi

if [ -n "${HYTALE_CURSEFORGE_API_KEY_SRC}" ]; then
  if [ ! -f "${HYTALE_CURSEFORGE_API_KEY_SRC}" ]; then
    log "WARNING: HYTALE_CURSEFORGE_API_KEY_SRC is set but file does not exist: ${HYTALE_CURSEFORGE_API_KEY_SRC}"
    if is_true "${HYTALE_CURSEFORGE_FAIL_ON_ERROR}"; then
      exit 1
    fi
    exit 0
  fi
  HYTALE_CURSEFORGE_API_KEY="$(cat "${HYTALE_CURSEFORGE_API_KEY_SRC}" 2>/dev/null || true)"
  HYTALE_CURSEFORGE_API_KEY="$(trim "${HYTALE_CURSEFORGE_API_KEY}")"
fi

if [ -z "${HYTALE_CURSEFORGE_API_KEY}" ]; then
  log "WARNING: HYTALE_CURSEFORGE_MODS is set but HYTALE_CURSEFORGE_API_KEY is empty"
  if is_true "${HYTALE_CURSEFORGE_FAIL_ON_ERROR}"; then
    exit 1
  fi
  exit 0
fi

EXPECTED_API_KEY_PREFIX='$2a$10$'
redact_api_key() {
  key="$1"
  prefix_len=7
  trailing=2
  total_len="${#key}"
  if [ "${total_len}" -le $((prefix_len + trailing)) ]; then
    printf '%s' "${key}" | cut -c1-$((total_len / 2))
  else
    printf '%s*****%s' "$(printf '%s' "${key}" | cut -c1-${prefix_len})" "$(printf '%s' "${key}" | tail -c ${trailing})"
  fi
}

log "CurseForge mods: validating API key format..."
case "${HYTALE_CURSEFORGE_API_KEY}" in
  '$$'*)
    log "ERROR: API key has extra dollar sign escaping"
    log "ERROR: Key looks like '$(redact_api_key "${HYTALE_CURSEFORGE_API_KEY}")' but should start with '${EXPECTED_API_KEY_PREFIX}'"
    log "ERROR: In Docker Compose, escape each \$ as \$\$ (so the key needs \$\$2a\$\$10\$\$...)"
    if is_true "${HYTALE_CURSEFORGE_FAIL_ON_ERROR}"; then
      exit 1
    fi
    exit 0
    ;;
  '$2a$10$'*)
    ;;
  *)
    log "ERROR: API key should start with '${EXPECTED_API_KEY_PREFIX}' but yours looks like '$(redact_api_key "${HYTALE_CURSEFORGE_API_KEY}")'"
    log "ERROR: Please verify your API key at https://console.curseforge.com/"
    log "ERROR: In Docker Compose, escape each \$ as \$\$ (so the key needs \$\$2a\$\$10\$\$...)"
    if is_true "${HYTALE_CURSEFORGE_FAIL_ON_ERROR}"; then
      exit 1
    fi
    exit 0
    ;;
esac

log "CurseForge mods: testing API key..."
test_api_url="${CF_API_BASE}/v1/games"
if [ -n "${HYTALE_CURSEFORGE_HTTP_CACHE_API_URL}" ]; then
  test_api_url="${HYTALE_CURSEFORGE_HTTP_CACHE_API_URL%/}/v1/games"
  test_http_code="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 15 --connect-timeout 10 -H "Host: ${CF_API_HOST}" -H "x-api-key: ${HYTALE_CURSEFORGE_API_KEY}" "${test_api_url}" 2>/dev/null || echo "000")"
else
  test_http_code="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 15 --connect-timeout 10 -H "x-api-key: ${HYTALE_CURSEFORGE_API_KEY}" "${test_api_url}" 2>/dev/null || echo "000")"
fi
if [ "${test_http_code}" != "200" ]; then
  log "ERROR: CurseForge API key test failed (HTTP ${test_http_code})"
  log "ERROR: Please verify your API key at https://console.curseforge.com/"
  if [ "${test_http_code}" = "403" ]; then
    log "ERROR: HTTP 403 = API key is invalid or lacks permissions"
  elif [ "${test_http_code}" = "000" ]; then
    log "ERROR: Could not connect to CurseForge API (network/timeout issue)"
  fi
  if is_true "${HYTALE_CURSEFORGE_FAIL_ON_ERROR}"; then
    exit 1
  fi
  log "WARNING: Continuing without CurseForge mods (HYTALE_CURSEFORGE_FAIL_ON_ERROR=false)"
  exit 0
fi
log "CurseForge mods: API key valid"

STATE_DIR="${DATA_DIR}/.hytale-curseforge-mods"
MANAGED_DIR="${STATE_DIR}"
DOWNLOADS_DIR="${MANAGED_DIR}/downloads"
FILES_DIR="${MANAGED_DIR}/files"
MANIFEST_PATH="${MANAGED_DIR}/manifest.json"

mkdir -p "${CF_MODS_DIR}" "${DOWNLOADS_DIR}" "${FILES_DIR}"
LOCK_DIR="${DATA_DIR}/.hytale-curseforge-mods-lock"
LOCK_CREATED_AT_PATH="${LOCK_DIR}/created_at_epoch"
LOCK_TTL_SECONDS=300
lock_acquired=0

cleanup() {
  if [ "${lock_acquired}" -eq 1 ]; then
    rm -rf "${LOCK_DIR}" 2>/dev/null || true
  fi
}

if is_true "${HYTALE_CURSEFORGE_LOCK}"; then
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
        log "CurseForge mods: stale lock detected at ${LOCK_DIR} (older than ${LOCK_TTL_SECONDS}s); removing"
        rm -rf "${LOCK_DIR}" 2>/dev/null || true
        continue
      fi
    fi

    log "CurseForge mods: another container may be installing mods into ${DATA_DIR}; waiting for lock (${LOCK_DIR})"
    sleep 3
  done

  if [ "${lock_acquired}" -ne 1 ]; then
    log "ERROR: CurseForge mods: could not acquire lock ${LOCK_DIR}"
    exit 1
  fi
else
  log "CurseForge mods: lock disabled via HYTALE_CURSEFORGE_LOCK=false"
fi
now_epoch="$(date +%s 2>/dev/null || echo 0)"

manifest_base='{"schemaVersion":1,"lastCheckEpoch":0,"mods":{}}'
if [ -f "${MANIFEST_PATH}" ]; then
  if ! jq -e . "${MANIFEST_PATH}" >/dev/null 2>&1; then
    log "CurseForge mods: invalid manifest JSON; recreating"
    printf '%s\n' "${manifest_base}" >"${MANIFEST_PATH}"
  fi
else
  printf '%s\n' "${manifest_base}" >"${MANIFEST_PATH}"
fi

last_check_epoch="$(jq -r '.lastCheckEpoch // 0' "${MANIFEST_PATH}" 2>/dev/null || echo 0)"
skip_remote_checks=0
if [ "${HYTALE_CURSEFORGE_CHECK_INTERVAL_SECONDS}" -gt 0 ] && [ "${last_check_epoch}" -gt 0 ]; then
  if [ $((now_epoch - last_check_epoch)) -lt "${HYTALE_CURSEFORGE_CHECK_INTERVAL_SECONDS}" ]; then
    skip_remote_checks=1
  fi
fi

release_allowed_expr="(.releaseType == 1)"
case "$(lower "${HYTALE_CURSEFORGE_RELEASE_CHANNEL}")" in
  release)
    release_allowed_expr="(.releaseType == 1)"
    ;;
  beta)
    release_allowed_expr="(.releaseType == 1 or .releaseType == 2)"
    ;;
  alpha|any)
    release_allowed_expr="(.releaseType == 1 or .releaseType == 2 or .releaseType == 3)"
    ;;
  *)
    log "ERROR: Invalid HYTALE_CURSEFORGE_RELEASE_CHANNEL value: ${HYTALE_CURSEFORGE_RELEASE_CHANNEL} (expected: release|beta|alpha|any)"
    exit 1
    ;;
esac

write_manifest() {
  tmp="${MANIFEST_PATH}.tmp.$$"
  jq . "${MANIFEST_PATH}" >"${tmp}"
  mv -f "${tmp}" "${MANIFEST_PATH}"
}

url_without_query() {
  url="${1:-}"
  printf '%s' "${url}" | sed 's/[?].*$//'
}

redact_url() {
  url_without_query "${1:-}"
}

safe_filename() {
  printf '%s' "${1:-}" | sed -e 's,[/[:space:]],_,g' -e 's/[^A-Za-z0-9._-]/_/g'
}

cf_last_http_code="000"
cf_last_rc=0
cf_last_url=""
cf_last_body=""

cf_get() {
  path="$1"
  url="${CF_API_BASE}${path}"
  host_header=""
  if [ -n "${HYTALE_CURSEFORGE_HTTP_CACHE_API_URL}" ]; then
    url="${HYTALE_CURSEFORGE_HTTP_CACHE_API_URL%/}${path}"
    host_header="${CF_API_HOST}"
  fi
  for attempt in 1 2 3; do
    out=""
    http_code="000"
    rc=0
    cf_last_url="$(redact_url "${url}")"
    set +e
    if [ -n "${host_header}" ]; then
      resp="$(curl -sS -L --max-time 30 --connect-timeout 10 -w '\n__HTTP_CODE__:%{http_code}' -H "Host: ${host_header}" -H "Accept: application/json" -H "x-api-key: ${HYTALE_CURSEFORGE_API_KEY}" "${url}" 2>/dev/null)"
      rc=$?
    else
      resp="$(curl -sS -L --max-time 30 --connect-timeout 10 -w '\n__HTTP_CODE__:%{http_code}' -H "Accept: application/json" -H "x-api-key: ${HYTALE_CURSEFORGE_API_KEY}" "${url}" 2>/dev/null)"
      rc=$?
    fi
    set -e

    http_code="$(printf '%s\n' "${resp}" | awk -F: '/^__HTTP_CODE__:/ {print $2}' | tail -n 1 2>/dev/null || echo "000")"
    out="$(printf '%s\n' "${resp}" | sed '$d' 2>/dev/null || true)"

    cf_last_http_code="${http_code}"
    cf_last_rc="${rc}"
    cf_last_body="${out}"

    case "${http_code}" in
      2??)
        if [ -n "${out}" ]; then
          return 0
        fi
        ;;
      429|5??)
        ;;
      4??)
        debug "API request failed (attempt ${attempt}/3, rc=${rc}, http=${http_code}): ${cf_last_url}"
        if [ -n "${out}" ]; then
          debug "API error body (truncated): $(printf '%s' "${out}" | cut -c1-200)"
        fi
        return 1
        ;;
    esac

    debug "API request failed (attempt ${attempt}/3, rc=${rc}, http=${http_code}): ${cf_last_url}"
    sleep "${attempt}"
  done
  return 1
}

download_and_install() {
  mod_id="$1"
  file_json="$2"
  file_id="$(printf '%s' "${file_json}" | jq -r '.id')"
  file_name="$(printf '%s' "${file_json}" | jq -r '.fileName')"
  release_type="$(printf '%s' "${file_json}" | jq -r '.releaseType // empty')"

  install_error_reason=""

  if ! cf_get "/v1/mods/${mod_id}/files/${file_id}/download-url"; then
    case "${cf_last_http_code}" in
      403)
        install_error_reason="failed to resolve download URL (CurseForge API returned HTTP 403 - the author may have disabled third-party/API downloads for this project)"
        ;;
      *)
        install_error_reason="failed to resolve download URL (CurseForge API request failed, http=${cf_last_http_code})"
        ;;
    esac
    return 1
  fi
  dl_json="${cf_last_body}"
  download_url="$(printf '%s' "${dl_json}" | jq -r '.data // empty')"
  if [ -z "${download_url}" ]; then
    install_error_reason="failed to resolve download URL (empty response)"
    return 1
  fi

  download_fetch_url="${download_url}"
  download_host_header=""
  if [ -n "${HYTALE_CURSEFORGE_HTTP_CACHE_DOWNLOAD_URL}" ]; then
    case "${download_url}" in
      http://*|https://*)
        rest="${download_url#*://}"
        download_host="${rest%%/*}"
        if [ "${rest#*/}" = "${rest}" ]; then
          download_path="/"
        else
          download_path="/${rest#*/}"
        fi
        download_fetch_url="${HYTALE_CURSEFORGE_HTTP_CACHE_DOWNLOAD_URL%/}${download_path}"
        download_host_header="${download_host}"
        ;;
    esac
  fi

  sha1="$(printf '%s' "${file_json}" | jq -r '.hashes[]? | select(.algo==1) | .value' 2>/dev/null | head -n 1 || true)"
  md5="$(printf '%s' "${file_json}" | jq -r '.hashes[]? | select(.algo==2) | .value' 2>/dev/null | head -n 1 || true)"

  dest_dir="${FILES_DIR}/${mod_id}/${file_id}"
  mkdir -p "${dest_dir}"
  dest_path="${dest_dir}/${file_name}"

  tmp_dl="${DOWNLOADS_DIR}/${mod_id}-${file_id}.tmp.$$"
  dl_ok=0
  http_code="000"
  rc=0
  set +e
  if [ -n "${download_host_header}" ]; then
    http_code="$(curl -sS -fL --max-time 300 --connect-timeout 30 --retry 3 --retry-delay 1 -H "Host: ${download_host_header}" -o "${tmp_dl}" -w "%{http_code}" "${download_fetch_url}" 2>/dev/null)"
    rc=$?
  else
    http_code="$(curl -sS -fL --max-time 300 --connect-timeout 30 --retry 3 --retry-delay 1 -o "${tmp_dl}" -w "%{http_code}" "${download_fetch_url}" 2>/dev/null)"
    rc=$?
  fi
  set -e
  if [ "${rc}" -eq 0 ]; then
    dl_ok=1
  fi
  if [ "${dl_ok}" -ne 1 ]; then
    rm -f "${tmp_dl}" 2>/dev/null || true
    install_error_reason="download failed (rc=${rc}, http=${http_code}, url=$(redact_url "${download_url}"))"
    debug "Download failed for mod ${mod_id} file ${file_id} (${file_name}) (rc=${rc}, http=${http_code})"
    debug "- download-url: $(redact_url "${download_url}")"
    debug "- fetch-url: $(redact_url "${download_fetch_url}")"
    return 1
  fi

  size_bytes="$(wc -c <"${tmp_dl}" 2>/dev/null | tr -d ' ' || true)"
  if [ -n "${size_bytes}" ]; then
    debug "Downloaded mod ${mod_id} file ${file_id} (${file_name}) size=${size_bytes} bytes"
  fi

  if [ -n "${sha1}" ]; then
    got="$(sha1sum "${tmp_dl}" 2>/dev/null | awk '{print $1}' || true)"
    if [ -z "${got}" ] || [ "${got}" != "${sha1}" ]; then
      rm -f "${tmp_dl}" 2>/dev/null || true
      install_error_reason="sha1 mismatch (expected=${sha1}, got=${got})"
      return 1
    fi
  elif [ -n "${md5}" ]; then
    got="$(md5sum "${tmp_dl}" 2>/dev/null | awk '{print $1}' || true)"
    if [ -z "${got}" ] || [ "${got}" != "${md5}" ]; then
      rm -f "${tmp_dl}" 2>/dev/null || true
      install_error_reason="md5 mismatch (expected=${md5}, got=${got})"
      return 1
    fi
  fi

  tmp_final="${dest_path}.tmp.$$"
  mv -f "${tmp_dl}" "${tmp_final}"
  mv -f "${tmp_final}" "${dest_path}"

  safe_name="$(safe_filename "${file_name}")"
  visible_name="cf-${mod_id}-${file_id}-${safe_name}"
  visible_path="${CF_MODS_DIR}/${visible_name}"

  if ln -sf "${dest_path}" "${visible_path}" 2>/dev/null; then
    :
  else
    cp -f "${dest_path}" "${visible_path}"
  fi

  installed_at="${now_epoch}"
  hash_algo=""
  hash_value=""
  if [ -n "${sha1}" ]; then
    hash_algo="sha1"
    hash_value="${sha1}"
  elif [ -n "${md5}" ]; then
    hash_algo="md5"
    hash_value="${md5}"
  fi

  ref="$(jq -r --arg mid "${mod_id}" '.mods[$mid].reference // empty' "${MANIFEST_PATH}" 2>/dev/null || true)"
  if [ -z "${ref}" ]; then
    ref="${mod_id}"
  fi

  tmp_manifest="${MANIFEST_PATH}.tmp.$$"
  jq \
    --arg mid "${mod_id}" \
    --arg ref "${ref}" \
    --arg fn "${file_name}" \
    --arg dn "$(printf '%s' "${file_json}" | jq -r '.displayName // empty')" \
    --arg fd "$(printf '%s' "${file_json}" | jq -r '.fileDate // empty')" \
    --arg url "${download_url}" \
    --arg ha "${hash_algo}" \
    --arg hv "${hash_value}" \
    --arg ip "${visible_name}" \
    --argjson fid "${file_id}" \
    --argjson rt "${release_type:-null}" \
    --argjson at "${installed_at}" \
    '(.mods[$mid] = {
      reference: $ref,
      resolved: {
        fileId: $fid,
        fileName: $fn,
        displayName: $dn,
        fileDate: $fd,
        releaseType: $rt,
        downloadUrl: $url,
        hash: (if ($ha != "" and $hv != "") then {algo: $ha, value: $hv} else null end)
      },
      installed: {
        fileId: $fid,
        path: $ip,
        installedAtEpoch: $at
      }
    })' "${MANIFEST_PATH}" >"${tmp_manifest}"
  mv -f "${tmp_manifest}" "${MANIFEST_PATH}"

  printf '%s\n' "${mod_id}"
}

resolve_best_file() {
  mod_id="$1"
  partial="$2"

  index=0
  page_size=50
  best_json=""
  best_date=""

  while :; do
    if ! cf_get "/v1/mods/${mod_id}/files?index=${index}&pageSize=${page_size}"; then
      break
    fi
    page="${cf_last_body}"
    count="$(printf '%s' "${page}" | jq -r '.data | length' 2>/dev/null || echo 0)"
    if [ "${count}" -eq 0 ]; then
      break
    fi

    filtered="$(printf '%s' "${page}" | jq -c \
      --arg gv "${HYTALE_CURSEFORGE_GAME_VERSION_FILTER}" \
      --arg part "${partial}" \
      --argjson haspart "$( [ -n "${partial}" ] && echo 1 || echo 0 )" \
      "[.data[]
        | select(.isAvailable == true)
        | select(${release_allowed_expr})
        | select((\$gv == \"\") or (.gameVersions[]? == \$gv))
        | select((\$haspart == 0) or (((.fileName // \"\") | ascii_downcase) | contains((\$part | ascii_downcase))) or (((.displayName // \"\") | ascii_downcase) | contains((\$part | ascii_downcase))))
      ] | sort_by(.fileDate) | last // empty" 2>/dev/null || true)"

    if [ -n "${filtered}" ] && [ "${filtered}" != "null" ]; then
      cand_date="$(printf '%s' "${filtered}" | jq -r '.fileDate // empty')"
      if [ -z "${best_date}" ] || [ "${cand_date}" \> "${best_date}" ]; then
        best_json="${filtered}"
        best_date="${cand_date}"
      fi
    fi

    index=$((index + page_size))
    if [ "${index}" -ge 10000 ]; then
      break
    fi
  done

  if [ -z "${best_json}" ] || [ "${best_json}" = "null" ]; then
    printf '%s' ""
    return 1
  fi

  printf '%s' "${best_json}"
}

errors=0
did_remote_check=0
installed_mod_ids=""

refs="$(expand_refs "${HYTALE_CURSEFORGE_MODS}")"

refs_file="$(mktemp /tmp/hytale-curseforge-mods.XXXXXX 2>/dev/null || mktemp)"
printf '%s\n' "${refs}" >"${refs_file}"

while IFS= read -r ref || [ -n "${ref}" ]; do
  ref="$(trim "${ref}")"
  if [ -z "${ref}" ]; then
    continue
  fi
  log "CurseForge mods: processing ${ref}"

  mod_id=""
  file_id=""
  partial=""

  case "${ref}" in
    *:*)
      mod_id="${ref%%:*}"
      file_id="${ref#*:}"
      ;;
    *@*)
      mod_id="${ref%%@*}"
      partial="${ref#*@}"
      ;;
    *)
      mod_id="${ref}"
      ;;
  esac

  case "${mod_id}" in
    *[!0-9]*|"")
      log "WARNING: invalid mod reference: ${ref}"
      continue
      ;;
  esac

  tmp_manifest="${MANIFEST_PATH}.tmp.$$"
  jq --arg mid "${mod_id}" --arg ref "${ref}" '(.mods[$mid].reference = $ref)' "${MANIFEST_PATH}" >"${tmp_manifest}"
  mv -f "${tmp_manifest}" "${MANIFEST_PATH}"

  if [ -n "${file_id}" ]; then
    case "${file_id}" in
      *[!0-9]*|"")
        log "WARNING: invalid mod reference: ${ref}"
        continue
        ;;
    esac

    if [ "${skip_remote_checks}" -eq 1 ]; then
      installed_path="$(jq -r --arg mid "${mod_id}" '.mods[$mid].installed.path // empty' "${MANIFEST_PATH}" 2>/dev/null || true)"
      if [ -n "${installed_path}" ] && [ -f "${CF_MODS_DIR}/${installed_path}" ]; then
        installed_mod_ids="${installed_mod_ids}${mod_id}\n"
        continue
      fi
    fi

    if ! cf_get "/v1/mods/${mod_id}/files/${file_id}"; then
      log "WARNING: could not resolve ${ref}"
      errors=$((errors + 1))
      continue
    fi
    file_resp="${cf_last_body}"
    file_json="$(printf '%s' "${file_resp}" | jq -c '.data // empty' 2>/dev/null || true)"
    if [ -z "${file_json}" ] || [ "${file_json}" = "null" ]; then
      log "WARNING: could not resolve ${ref}"
      errors=$((errors + 1))
      continue
    fi
    did_remote_check=1
  else
    installed_file_id="$(jq -r --arg mid "${mod_id}" '.mods[$mid].installed.fileId // empty' "${MANIFEST_PATH}" 2>/dev/null || true)"
    installed_path="$(jq -r --arg mid "${mod_id}" '.mods[$mid].installed.path // empty' "${MANIFEST_PATH}" 2>/dev/null || true)"

    if [ "${skip_remote_checks}" -eq 1 ] && [ -n "${installed_file_id}" ] && [ -n "${installed_path}" ] && [ -f "${CF_MODS_DIR}/${installed_path}" ]; then
      installed_mod_ids="${installed_mod_ids}${mod_id}\n"
      continue
    fi

    if ! is_true "${HYTALE_CURSEFORGE_AUTO_UPDATE}" && [ -n "${installed_file_id}" ] && [ -n "${installed_path}" ] && [ -f "${CF_MODS_DIR}/${installed_path}" ]; then
      installed_mod_ids="${installed_mod_ids}${mod_id}\n"
      continue
    fi

    file_json="$(resolve_best_file "${mod_id}" "${partial}" || true)"
    if [ -z "${file_json}" ]; then
      log "WARNING: could not resolve ${ref}"
      errors=$((errors + 1))
      continue
    fi
    did_remote_check=1
  fi

  resolved_file_id="$(printf '%s' "${file_json}" | jq -r '.id')"
  safe_name="$(safe_filename "$(printf '%s' "${file_json}" | jq -r '.fileName')")"
  visible_name="cf-${mod_id}-${resolved_file_id}-${safe_name}"

  current_file_id="$(jq -r --arg mid "${mod_id}" '.mods[$mid].installed.fileId // empty' "${MANIFEST_PATH}" 2>/dev/null || true)"
  current_path="$(jq -r --arg mid "${mod_id}" '.mods[$mid].installed.path // empty' "${MANIFEST_PATH}" 2>/dev/null || true)"

  if [ -n "${current_file_id}" ] && [ "${current_file_id}" = "${resolved_file_id}" ] && [ -n "${current_path}" ] && [ -f "${CF_MODS_DIR}/${current_path}" ]; then
    installed_mod_ids="${installed_mod_ids}${mod_id}\n"
    continue
  fi

  if ! download_and_install "${mod_id}" "${file_json}" >/dev/null; then
    if [ -n "${install_error_reason}" ]; then
      log "WARNING: failed to install mod ${mod_id}: ${install_error_reason}"
    else
      log "WARNING: failed to install mod ${mod_id}"
    fi
    errors=$((errors + 1))
    continue
  fi

  installed_mod_ids="${installed_mod_ids}${mod_id}\n"
  if [ "${visible_name}" != "${current_path}" ] && [ -n "${current_path}" ] && [ -f "${CF_MODS_DIR}/${current_path}" ]; then
    rm -f "${CF_MODS_DIR}/${current_path}" 2>/dev/null || true
  fi

done <"${refs_file}"

rm -f "${refs_file}" 2>/dev/null || true

if [ "${did_remote_check}" -eq 1 ]; then
  tmp_manifest="${MANIFEST_PATH}.tmp.$$"
  jq --argjson now "${now_epoch}" '.lastCheckEpoch = $now' "${MANIFEST_PATH}" >"${tmp_manifest}"
  mv -f "${tmp_manifest}" "${MANIFEST_PATH}"
fi

if is_true "${HYTALE_CURSEFORGE_PRUNE}"; then
  desired_ids_file="${MANAGED_DIR}/.desired_mod_ids.$$"
  printf '%b' "${installed_mod_ids}" | sort -u >"${desired_ids_file}" 2>/dev/null || true

  jq -r '.mods | keys[]' "${MANIFEST_PATH}" 2>/dev/null | while IFS= read -r mid || [ -n "${mid}" ]; do
    if ! grep -qx "${mid}" "${desired_ids_file}" 2>/dev/null; then
      old_path="$(jq -r --arg mid "${mid}" '.mods[$mid].installed.path // empty' "${MANIFEST_PATH}" 2>/dev/null || true)"
      if [ -n "${old_path}" ] && [ -e "${CF_MODS_DIR}/${old_path}" ]; then
        rm -f "${CF_MODS_DIR}/${old_path}" 2>/dev/null || true
      fi
      rm -rf "${FILES_DIR}/${mid}" 2>/dev/null || true

      tmp_manifest="${MANIFEST_PATH}.tmp.$$"
      jq --arg mid "${mid}" 'del(.mods[$mid])' "${MANIFEST_PATH}" >"${tmp_manifest}"
      mv -f "${tmp_manifest}" "${MANIFEST_PATH}"
    fi
  done

  rm -f "${desired_ids_file}" 2>/dev/null || true
fi

if [ "${errors}" -gt 0 ] && is_true "${HYTALE_CURSEFORGE_FAIL_ON_ERROR}"; then
  exit 1
fi

exit 0
