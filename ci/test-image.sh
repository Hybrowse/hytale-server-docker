#!/bin/sh
set -eu

IMAGE_NAME="${IMAGE_NAME:-hytale-server:test}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*" >&2
}

# Test 1: runs as non-root by default
uid="$(docker run --rm --entrypoint id "${IMAGE_NAME}" -u)"
[ "${uid}" = "1000" ] || fail "expected uid 1000, got ${uid}"
pass "default user is non-root (uid=${uid})"

# Test 2: fails fast with clear errors when files are missing
workdir="$(mktemp -d)"
chmod 0777 "${workdir}"
set +e
out="$(docker run --rm -v "${workdir}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected non-zero exit status when files missing"
echo "${out}" | grep -q "Missing server jar" || fail "missing server jar error not present"
echo "${out}" | grep -q "Missing assets" || fail "missing assets error not present"
echo "${out}" | grep -q "Expected volume layout:" || fail "expected volume layout help not present"
echo "${out}" | grep -q "docs/image/server-files.md" || fail "expected docs link to server-files.md"
if echo "${out}" | grep -q "docs/hytale/"; then
  fail "output should not reference docs/hytale"
fi
pass "fails fast when Assets.zip / jar missing"

rm -rf "${workdir}"

# Test 3: AOT strict mode fails when cache missing
workdir="$(mktemp -d)"
chmod 0777 "${workdir}"
mkdir -p "${workdir}/server"
chmod 0777 "${workdir}/server"
: > "${workdir}/Assets.zip"
: > "${workdir}/server/HytaleServer.jar"
set +e
out="$(docker run --rm -e ENABLE_AOT=true -v "${workdir}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected non-zero exit status when ENABLE_AOT=true and cache missing"
echo "${out}" | grep -q "ENABLE_AOT=true" || fail "AOT strict error not present"
pass "ENABLE_AOT=true fails fast when cache missing"

# Test 3b: backup flag is recognized by the entrypoint
set +e
out="$(docker run --rm -e HYTALE_ENABLE_BACKUP=true -v "${workdir}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected non-zero exit status due to dummy jar"
echo "${out}" | grep -q "Backup: enabled" || fail "expected backup enabled log"
pass "backup can be enabled via HYTALE_ENABLE_BACKUP"

# Test 3c: pre-start downloads must fail fast on unsupported URL schemes (no network)
bad_urls="$(printf '%s\n' \
  "ftp://example.com/mod-a.zip, ftp://example.com/mod-b.zip" \
  "ftp://example.com/mod-c.zip")"
set +e
out="$(docker run --rm \
  -e "HYTALE_MODS_DOWNLOAD_URLS=${bad_urls}" \
  -v "${workdir}:/data" \
  "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected non-zero exit status when mods download URL scheme is unsupported"
echo "${out}" | grep -qF "ftp://example.com/mod-a.zip" || fail "expected mod-a URL to appear in output"
echo "${out}" | grep -qF "ftp://example.com/mod-b.zip" || fail "expected mod-b URL to appear in output"
echo "${out}" | grep -qF "ftp://example.com/mod-c.zip" || fail "expected mod-c URL to appear in output"
count="$(printf '%s' "${out}" | grep -cF "unsupported URL scheme" 2>/dev/null || true)"
[ "${count}" -eq 3 ] || fail "expected 3 unsupported scheme errors (comma + newline parsing), got ${count}"
pass "pre-start downloads fail fast on unsupported URL schemes"

# Test 4: auto-download must refuse non-official downloader URLs (no network)
workdir2="$(mktemp -d)"
chmod 0777 "${workdir2}"
set +e
out="$(docker run --rm \
  -e HYTALE_AUTO_DOWNLOAD=true \
  -e HYTALE_DOWNLOADER_URL=https://example.com/hytale-downloader.zip \
  -v "${workdir2}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected non-zero exit status when HYTALE_DOWNLOADER_URL is not official"
echo "${out}" | grep -q "Attempting auto-download via official Hytale Downloader" || fail "expected entrypoint to attempt auto-download"
if echo "${out}" | grep -q "ERROR: Missing server jar"; then
  fail "auto-download mode should not prefix missing server jar with ERROR"
fi
if echo "${out}" | grep -q "ERROR: Missing assets"; then
  fail "auto-download mode should not prefix missing assets with ERROR"
fi
echo "${out}" | grep -q "must start with https://downloader.hytale.com/" || fail "expected downloader URL allowlist error"
pass "auto-download rejects non-official downloader URL"
rm -rf "${workdir2}"

# Test 4b: auto-update is enabled by default when files are present
workdir2b="$(mktemp -d)"
chmod 0777 "${workdir2b}"
mkdir -p "${workdir2b}/server"
chmod 0777 "${workdir2b}/server"
: > "${workdir2b}/Assets.zip"
: > "${workdir2b}/server/HytaleServer.jar"
set +e
out="$(docker run --rm \
  -e HYTALE_AUTO_DOWNLOAD=true \
  -e HYTALE_DOWNLOADER_URL=https://example.com/hytale-downloader.zip \
  -v "${workdir2b}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected non-zero exit status when auto-update attempts downloader with invalid URL"
echo "${out}" | grep -q "Attempting auto-download via official Hytale Downloader" || fail "expected entrypoint to attempt auto-download when files exist"
echo "${out}" | grep -q "server files already present; checking for updates" || fail "expected auto-download to check for updates when files exist"
echo "${out}" | grep -q "must start with https://downloader.hytale.com/" || fail "expected downloader URL allowlist error"
pass "auto-update runs downloader when files exist"
rm -rf "${workdir2b}"

# Test 4c: auto-update can be disabled via HYTALE_AUTO_UPDATE=false
workdir2c="$(mktemp -d)"
chmod 0777 "${workdir2c}"
mkdir -p "${workdir2c}/server"
chmod 0777 "${workdir2c}/server"
: > "${workdir2c}/Assets.zip"
: > "${workdir2c}/server/HytaleServer.jar"
set +e
out="$(docker run --rm \
  -e HYTALE_AUTO_DOWNLOAD=true \
  -e HYTALE_AUTO_UPDATE=false \
  -e HYTALE_DOWNLOADER_URL=https://example.com/hytale-downloader.zip \
  -v "${workdir2c}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected non-zero exit status due to dummy jar"
if echo "${out}" | grep -q "Attempting auto-download via official Hytale Downloader"; then
  fail "did not expect entrypoint to attempt auto-download when HYTALE_AUTO_UPDATE=false"
fi
if echo "${out}" | grep -q "must start with https://downloader.hytale.com/"; then
  fail "did not expect downloader URL allowlist error when HYTALE_AUTO_UPDATE=false"
fi
echo "${out}" | grep -q "Starting Hytale dedicated server" || fail "expected server start log when auto-update disabled"
pass "auto-update can be disabled"
rm -rf "${workdir2c}"

# Test 5: auto-download must fail fast on arm64 without attempting network calls
# Use HYTALE_TEST_ARCH to simulate arm64 on any runner.
workdir3="$(mktemp -d)"
chmod 0777 "${workdir3}"
set +e
out="$(docker run --rm \
  --entrypoint /usr/local/bin/hytale-auto-download \
  -e HYTALE_TEST_ARCH=aarch64 \
  -v "${workdir3}:/data" \
  "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected non-zero exit status when auto-download is forced to arm64"
echo "${out}" | grep -q "Auto-download is not supported on arm64" || fail "expected arm64 unsupported error"
echo "${out}" | grep -q "provide server files and Assets.zip manually" || fail "expected manual provisioning hint on arm64"
pass "auto-download fails fast on arm64"
rm -rf "${workdir3}"

# Test 6: stale auto-download lock must be removed automatically
workdir4="$(mktemp -d)"
chmod 0777 "${workdir4}"
mkdir -p "${workdir4}/.hytale-download-lock"
now_epoch="$(date +%s)"
stale_epoch=$((now_epoch - 600))
printf '%s\n' "${stale_epoch}" >"${workdir4}/.hytale-download-lock/created_at_epoch"

set +e
out="$(docker run --rm \
  --entrypoint /usr/local/bin/hytale-auto-download \
  -v "${workdir4}:/data" \
  -e HYTALE_DOWNLOADER_URL=https://example.com/hytale-downloader.zip \
  "${IMAGE_NAME}" 2>&1)"
status=$?
set -e

[ ${status} -ne 0 ] || fail "expected non-zero exit status due to invalid HYTALE_DOWNLOADER_URL"
echo "${out}" | grep -q "stale lock detected" || fail "expected stale lock removal log"
pass "stale lock is removed automatically"
rm -rf "${workdir4}"

# Test 7: tokens must never be logged as values
TOKEN_VALUE="super-secret-token"
: > "${workdir}/server/HytaleServer.aot" || true
set +e
out="$(docker run --rm \
  -e HYTALE_SERVER_SESSION_TOKEN="${TOKEN_VALUE}" \
  -e HYTALE_SERVER_IDENTITY_TOKEN="${TOKEN_VALUE}" \
  -v "${workdir}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected java to fail with dummy jar, but got status 0"
echo "${out}" | grep -q "\[set\]" || fail "expected token placeholders in logs"
if echo "${out}" | grep -q "${TOKEN_VALUE}"; then
  fail "token value was logged"
fi
pass "token values are not logged"

workdir_cf="$(mktemp -d)"
chmod 0777 "${workdir_cf}"
cf_net="cf-mock-$$"
cf_mock_name="cf-mock-$$"

cf_cleanup() {
  if [ -n "${cf_mock_cid:-}" ]; then
    docker stop "${cf_mock_cid}" >/dev/null 2>&1 || true
  fi
  docker network rm "${cf_net}" >/dev/null 2>&1 || true
  rm -rf "${workdir_cf}" || true
}

trap cf_cleanup EXIT INT TERM

docker network create "${cf_net}" >/dev/null 2>&1 || fail "failed to create docker network ${cf_net}"

cf_mock_cid="$(docker run -d --rm --name "${cf_mock_name}" --network "${cf_net}" python:3.12-alpine \
  python -u -c '
import http.server
import socketserver
import json

class H(http.server.BaseHTTPRequestHandler):
  def do_GET(self):
    p = self.path.split("?", 1)[0]
    if p == "/v1/games":
      self.send_response(200)
      self.send_header("Content-Type", "application/json")
      self.end_headers()
      self.wfile.write(b"{}")
      return

    if p == "/v1/mods/1429212/files/7497865":
      body = json.dumps({"data": {"id": 7497865, "fileName": "gravestones.jar", "releaseType": 1, "hashes": []}}).encode("utf-8")
      self.send_response(200)
      self.send_header("Content-Type", "application/json")
      self.send_header("Content-Length", str(len(body)))
      self.end_headers()
      self.wfile.write(body)
      return

    if p == "/v1/mods/1429212/files/7497865/download-url":
      self.send_response(403)
      self.end_headers()
      return

    self.send_response(404)
    self.end_headers()

  def log_message(self, fmt, *args):
    return

socketserver.TCPServer.allow_reuse_address = True
socketserver.TCPServer(("0.0.0.0", 8080), H).serve_forever()
' 2>/dev/null)"

[ -n "${cf_mock_cid}" ] || fail "failed to start mock CurseForge API server"

ready=0
for _i in 1 2 3 4 5 6 7 8 9 10; do
  if docker exec "${cf_mock_name}" python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/v1/games', timeout=1).read()" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 0.2
done
[ "${ready}" -eq 1 ] || fail "mock CurseForge API server did not become ready"

set +e
out="$(docker run --rm --network "${cf_net}" \
  --entrypoint /usr/local/bin/hytale-curseforge-mods \
  -e HYTALE_CURSEFORGE_DEBUG=true \
  -e HYTALE_CURSEFORGE_FAIL_ON_ERROR=true \
  -e HYTALE_CURSEFORGE_HTTP_CACHE_API_URL="http://${cf_mock_name}:8080" \
  -e HYTALE_CURSEFORGE_MODS="1429212:7497865" \
  -e HYTALE_CURSEFORGE_API_KEY='$2a$10$0000000000000000000000' \
  -v "${workdir_cf}:/data" \
  "${IMAGE_NAME}" 2>&1)"
status=$?
set -e

trap - EXIT INT TERM
cf_cleanup

[ ${status} -ne 0 ] || fail "expected non-zero exit status when CurseForge mod install fails with HYTALE_CURSEFORGE_FAIL_ON_ERROR=true"
if ! echo "${out}" | grep -q "WARNING: failed to install mod 1429212"; then
  echo "${out}" >&2
  fail "expected mod install failure warning"
fi
echo "${out}" | grep -q "CurseForge API returned HTTP 403" || fail "expected actionable HTTP 403 hint"
if printf '%s' "${out}" | grep -qF "attempt 2/3" 2>/dev/null; then
  fail "did not expect retry attempt 2/3 on HTTP 403"
fi
count="$(printf '%s' "${out}" | grep -cF "attempt 1/3" 2>/dev/null || true)"
[ "${count}" -eq 1 ] || fail "expected exactly one attempt on HTTP 403 (attempt 1/3), got ${count}"
pass "CurseForge mods HTTP 403 has actionable hint and does not retry"

# Test 7b: token broker must fail fast when enabled without URL
set +e
out="$(docker run --rm \
  -e HYTALE_SESSION_TOKEN_BROKER_ENABLED=true \
  -v "${workdir}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected non-zero exit status when broker enabled without URL"
echo "${out}" | grep -q "HYTALE_SESSION_TOKEN_BROKER_URL is empty" || fail "expected missing broker URL error"
pass "broker fails fast when enabled without URL"

# Test 7c: token broker can continue on error when configured
set +e
out="$(docker run --rm \
  -e HYTALE_SESSION_TOKEN_BROKER_ENABLED=true \
  -e HYTALE_SESSION_TOKEN_BROKER_URL=http://127.0.0.1:9 \
  -e HYTALE_SESSION_TOKEN_BROKER_TIMEOUT_SECONDS=1 \
  -e HYTALE_SESSION_TOKEN_BROKER_FAIL_ON_ERROR=false \
  -v "${workdir}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected java to fail with dummy jar"
echo "${out}" | grep -q "Continuing without token broker tokens" || fail "expected broker continue warning"
echo "${out}" | grep -q "Starting Hytale dedicated server" || fail "expected server start log when broker continues"
pass "broker can continue on error"

# Test 7d: broker bearer token from file must never be logged
BROKER_TOKEN_VALUE="broker-bearer-super-secret"
token_file="$(mktemp)"
printf '%s' "${BROKER_TOKEN_VALUE}" >"${token_file}"
set +e
out="$(docker run --rm \
  -e HYTALE_SESSION_TOKEN_BROKER_ENABLED=true \
  -e HYTALE_SESSION_TOKEN_BROKER_URL=http://127.0.0.1:9 \
  -e HYTALE_SESSION_TOKEN_BROKER_TIMEOUT_SECONDS=1 \
  -e HYTALE_SESSION_TOKEN_BROKER_FAIL_ON_ERROR=false \
  -e HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC=/run/secrets/broker_bearer_token \
  -v "${token_file}:/run/secrets/broker_bearer_token:ro" \
  -v "${workdir}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
rm -f "${token_file}" || true
[ ${status} -ne 0 ] || fail "expected java to fail with dummy jar"
if echo "${out}" | grep -q "${BROKER_TOKEN_VALUE}"; then
  fail "broker bearer token value was logged"
fi
pass "broker bearer token value is not logged"

# Test 8: machine-id is generated and persisted
workdir5="$(mktemp -d)"
chmod 0777 "${workdir5}"
mkdir -p "${workdir5}/server"
chmod 0777 "${workdir5}/server"
: > "${workdir5}/Assets.zip"
: > "${workdir5}/server/HytaleServer.jar"
set +e
out="$(docker run --rm -v "${workdir5}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected java to fail with dummy jar"
[ -f "${workdir5}/.machine-id" ] || fail "expected .machine-id to be created"
machine_id="$(cat "${workdir5}/.machine-id")"
[ "${#machine_id}" -eq 32 ] || fail "expected machine-id to be 32 characters, got ${#machine_id}"
echo "${machine_id}" | grep -qE '^[0-9a-f]{32}$' || fail "expected machine-id to be lowercase hex"
if echo "${out}" | grep -q "${machine_id}"; then
  fail "machine-id value should not be logged"
fi
pass "machine-id is generated and persisted"

# Test 8b: machine-id is stable across restarts
set +e
out2="$(docker run --rm -v "${workdir5}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected java to fail with dummy jar"
machine_id2="$(cat "${workdir5}/.machine-id")"
[ "${machine_id}" = "${machine_id2}" ] || fail "expected machine-id to be stable, got ${machine_id} vs ${machine_id2}"
pass "machine-id is stable across restarts"

# Test 8c: HYTALE_MACHINE_ID can override machine-id
CUSTOM_MACHINE_ID="0123456789abcdef0123456789abcdef"
set +e
out3="$(docker run --rm -e HYTALE_MACHINE_ID="${CUSTOM_MACHINE_ID}" -v "${workdir5}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected java to fail with dummy jar"
machine_id3="$(cat "${workdir5}/.machine-id")"
[ "${machine_id3}" = "${CUSTOM_MACHINE_ID}" ] || fail "expected custom machine-id to be used, got ${machine_id3}"
if echo "${out3}" | grep -q "${CUSTOM_MACHINE_ID}"; then
  fail "custom machine-id value should not be logged"
fi
pass "HYTALE_MACHINE_ID can override machine-id"

rm -rf "${workdir5}"

# Test 9: permission check fails when /data is not writable
# Note: We can't use :ro mount because Docker's WORKDIR fails before entrypoint runs.
# Instead, create a directory owned by root that the container user (1000) cannot write to.
workdir6="$(mktemp -d)"
mkdir -p "${workdir6}/server"
chmod 0777 "${workdir6}/server"
chmod 0555 "${workdir6}"
set +e
out="$(docker run --rm -v "${workdir6}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected non-zero exit status when /data is not writable"
echo "${out}" | grep -q "Cannot write to /data" || fail "expected /data not writable error"
echo "${out}" | grep -q "troubleshooting.md" || fail "expected troubleshooting docs link"
pass "permission check fails when /data is not writable"
chmod 0755 "${workdir6}"
rm -rf "${workdir6}"

# Test 10: permission check fails when /data/server exists but is not writable
workdir7="$(mktemp -d)"
chmod 0777 "${workdir7}"
mkdir -p "${workdir7}/server"
chmod 0555 "${workdir7}/server"
set +e
out="$(docker run --rm -v "${workdir7}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected non-zero exit status when /data/server is not writable"
echo "${out}" | grep -q "Cannot write to /data/server" || fail "expected /data/server not writable error"
echo "${out}" | grep -q "Current owner:" || fail "expected current owner info in error"
echo "${out}" | grep -q "troubleshooting.md" || fail "expected troubleshooting docs link"
pass "permission check fails when /data/server is not writable"
chmod 0755 "${workdir7}/server"
rm -rf "${workdir7}"

# Test 11: read-only root filesystem does not cause machine-id error output
workdir8="$(mktemp -d)"
chmod 0777 "${workdir8}"
mkdir -p "${workdir8}/server"
chmod 0777 "${workdir8}/server"
: > "${workdir8}/Assets.zip"
: > "${workdir8}/server/HytaleServer.jar"
set +e
out="$(docker run --rm --read-only --tmpfs /tmp -v "${workdir8}:/data" "${IMAGE_NAME}" 2>&1)"
status=$?
set -e
[ ${status} -ne 0 ] || fail "expected java to fail with dummy jar"
if echo "${out}" | grep -q "cannot create /etc/machine-id"; then
  fail "machine-id error should be suppressed on read-only root filesystem"
fi
[ -f "${workdir8}/.machine-id" ] || fail "expected .machine-id to be created on /data"
pass "read-only root filesystem does not cause machine-id error output"
rm -rf "${workdir8}"

mods_multiline="$(printf '%s\n' \
  '1409700 # Serilum Hybrid' \
  '1423805 # Serilum WelcomeMessage' \
  '1405415 # SimpleClaims' \
  '1409811 # AdvancedItemInfo')"
out="$(docker run --rm \
  --entrypoint /usr/local/bin/hytale-curseforge-mods \
  -e HYTALE_CURSEFORGE_EXPAND_REFS_ONLY=true \
  -e "HYTALE_CURSEFORGE_MODS=${mods_multiline}" \
  "${IMAGE_NAME}" 2>&1)"
echo "${out}" | grep -qx "1409700" || fail "expected multiline mods parsing to include 1409700"
echo "${out}" | grep -qx "1423805" || fail "expected multiline mods parsing to include 1423805"
echo "${out}" | grep -qx "1405415" || fail "expected multiline mods parsing to include 1405415"
echo "${out}" | grep -qx "1409811" || fail "expected multiline mods parsing to include 1409811"
if echo "${out}" | grep -q "#"; then
  fail "expected inline comments to be stripped from mod refs"
fi
if echo "${out}" | grep -qi "serilum"; then
  fail "expected comment text to be stripped from mod refs"
fi
pass "multiline HYTALE_CURSEFORGE_MODS supports inline comments"

rm -rf "${workdir}"
pass "all tests"
