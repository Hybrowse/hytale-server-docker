#!/bin/sh
set -eu
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HYTALE_TEST_ARCH=amd64 sh "${ROOT_DIR}/ci/test-downloader.sh"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT INT TERM
cat > "${workdir}/qemu-x86_64-static" <<'QEMU'
#!/bin/sh
printf '%s\n' "$2" >> "${TEST_QEMU_CALLS}"
exec "$@"
QEMU
chmod +x "${workdir}/qemu-x86_64-static"
PATH="${workdir}:${PATH}" TEST_QEMU_CALLS="${workdir}/calls" HYTALE_TEST_ARCH=aarch64 \
  sh "${ROOT_DIR}/ci/test-downloader.sh"
grep -q -- '-print-version' "${workdir}/calls"
grep -q -- '-download-path' "${workdir}/calls"
printf '%s\n' 'PASS: ARM64 uses the same emulator for version checks and downloads'
