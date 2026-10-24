#!/bin/sh
set -eu
IMAGE_NAME="${IMAGE_NAME:-hytale-server:test}"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT INT TERM
chmod 0777 "${workdir}"
mkdir "${workdir}/server"
chmod 0777 "${workdir}/server"
: > "${workdir}/server/HytaleServer.jar"
: > "${workdir}/Assets.zip"
cat > "${workdir}/java" <<'JAVA'
#!/bin/sh
printf '%s\n' "$@" > /data/java-args
JAVA
chmod 0755 "${workdir}/java"
run_image() {
  docker run --rm -e ENABLE_AOT=false -e HYTALE_CONSOLE_PIPE=false \
    -v "${workdir}:/data" -v "${workdir}/java:/opt/java/openjdk/bin/java:ro" \
    "$@" "${IMAGE_NAME}"
}
run_image \
  -e 'HYTALE_GENERATE_ASSET_SCHEMA_PATH=/data/asset schemas' \
  -e 'HYTALE_GENERATE_CONFIG_SCHEMA_PATH=/data/config schemas' \
  -e HYTALE_IGNORE_BROKEN_MODS=true \
  -e HYTALE_VERIFY_WORLDS=true \
  -e HYTALE_RECOVERY_MODE=FROM_BACKUP_OR_REGENERATE >/dev/null 2>&1
for arg in --generate-asset-schema '/data/asset schemas' --generate-config-schema '/data/config schemas' --ignore-broken-mods --verify-worlds --recovery-mode FROM_BACKUP_OR_REGENERATE; do
  grep -Fx -- "$arg" "${workdir}/java-args" >/dev/null || { echo "Missing argument: $arg" >&2; exit 1; }
done
expect_error() {
  expected="$1"
  shift
  rm -f "${workdir}/java-args"
  if out="$(run_image "$@" 2>&1)"; then
    echo "Expected configuration failure" >&2; exit 1
  fi
  printf '%s\n' "$out" | grep -F "$expected" >/dev/null || { echo "Missing migration guidance" >&2; exit 1; }
  [ ! -e "${workdir}/java-args" ] || { echo "Java ran despite invalid configuration" >&2; exit 1; }
}
expect_error HYTALE_GENERATE_ASSET_SCHEMA_PATH -e HYTALE_GENERATE_SCHEMA=true
expect_error HYTALE_IGNORE_BROKEN_MODS -e HYTALE_SKIP_MOD_VALIDATION=true
expect_error 'requires HYTALE_VERIFY_WORLDS' -e HYTALE_RECOVERY_MODE=REGENERATE
expect_error 'must be FROM_BACKUP_OR_REGENERATE or REGENERATE' -e HYTALE_VERIFY_WORLDS=true -e HYTALE_RECOVERY_MODE=typo
echo 'PASS: Hytale 0.7.4 options and migration guidance'
