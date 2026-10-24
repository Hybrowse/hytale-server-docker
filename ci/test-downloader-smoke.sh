#!/bin/sh
set -eu
IMAGE_NAME="${IMAGE_NAME:-hytale-server:test}"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT INT TERM
chmod 0755 "${workdir}"
curl -fsSL --max-time 120 https://downloader.hytale.com/hytale-downloader.zip -o "${workdir}/downloader.zip"
unzip -p "${workdir}/downloader.zip" hytale-downloader-linux-amd64 > "${workdir}/downloader"
chmod 0755 "${workdir}/downloader"
docker run --rm --entrypoint sh -v "${workdir}/downloader:/probe/downloader:ro" "${IMAGE_NAME}" -ec '
  case "$(uname -m)" in
    aarch64|arm64) qemu-x86_64-static /probe/downloader -version ;;
    x86_64) /probe/downloader -version ;;
    *) exit 1 ;;
  esac
  java -XshowSettings:properties -version 2>&1 | sed -n "/os.arch = /p"
'
