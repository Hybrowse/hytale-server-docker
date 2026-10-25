#!/bin/sh
# Black-box checks against the same final image that users run.
set -eu
IMAGE_NAME="${IMAGE_NAME:-hytale-server:test}"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

# No entrypoint/server, network, writable root filesystem or console FIFO needed.
docker run --rm --network none --read-only --tmpfs /tmp \
  -e HYTALE_CONSOLE_PIPE=false --entrypoint hytale-cli "$IMAGE_NAME" doctor --help > "$test_dir/help"
grep -q 'Read-only local checks' "$test_dir/help"
set +e
docker run --rm --network none --read-only --tmpfs /tmp --memory 2g --cpus 1 \
  -e HYTALE_CONSOLE_PIPE=false -e JVM_XMX=2G \
  -e HYTALE_SERVER_SESSION_TOKEN=PRIVATE_SESSION_CANARY \
  -e HYTALE_SERVER_IDENTITY_TOKEN=PRIVATE_IDENTITY_CANARY \
  -e HYTALE_SESSION_TOKEN_BROKER_URL=https://PRIVATE_HOST_CANARY.invalid \
  --entrypoint hytale-cli "$IMAGE_NAME" report > "$test_dir/report" 2> "$test_dir/stderr"
result=$?
set -e
[ "$result" -eq 1 ] # Missing files and heap equal to memory limit.
jq -e '.schema_version == 1 and .status == "error" and .network_checks == false and (.architecture == "arm64" or .architecture == "amd64")' "$test_dir/report" >/dev/null
jq -e '.checks[] | select(.id == "resources.heap" and .status == "error")' "$test_dir/report" >/dev/null
jq -e '.checks[] | select(.id == "network.outbound" and .status == "unknown")' "$test_dir/report" >/dev/null
if grep -q 'PRIVATE_.*CANARY' "$test_dir/report" "$test_dir/stderr"; then
  echo 'Diagnostic output exposed an input canary' >&2
  exit 1
fi
set +e
docker run --rm --network none --entrypoint hytale-cli "$IMAGE_NAME" status --PRIVATE_OPTION_CANARY > "$test_dir/invalid" 2>&1
result=$?
set -e
[ "$result" -eq 2 ]
! grep -q PRIVATE_OPTION_CANARY "$test_dir/invalid"
echo 'Read-only diagnostic image tests passed.'
