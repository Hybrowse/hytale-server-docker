#!/bin/sh
set -eu
IMAGE_NAME="${IMAGE_NAME:-hytale-server:test}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT INT TERM
chmod 0755 "${workdir}"
mkdir "${workdir}/jar" "${workdir}/assets"
printf 'old jar' > "${workdir}/jar/version"
(cd "${workdir}/jar" && zip -q "${workdir}/old.jar" version)
printf 'new jar' > "${workdir}/jar/version"
(cd "${workdir}/jar" && zip -q "${workdir}/new.jar" version)
printf 'old assets' > "${workdir}/assets/version"
(cd "${workdir}/assets" && zip -q "${workdir}/old-assets.zip" version)
printf 'new assets' > "${workdir}/assets/version"
(cd "${workdir}/assets" && zip -q "${workdir}/new-assets.zip" version)
chmod -R a+rX "${workdir}"
docker run --rm --entrypoint sh \
  -v "${workdir}:/fixture:ro" \
  -v "${ROOT_DIR}/ci/test-native-updates-container.sh:/probe.sh:ro" \
  "${IMAGE_NAME}" /probe.sh
