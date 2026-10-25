#!/bin/sh
set -eu
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Local tools avoid pulling test images on developer machines. CI uses the pinned
# Docker tools so Helm/Kustomize versions stay reproducible.
if [ "${K8S_TEST_TOOLS:-docker}" != local ]; then
  for image in alpine/helm:4.3.1 registry.k8s.io/kustomize/kustomize:v5.8.3 ghcr.io/yannh/kubeconform:v0.8.0; do
    docker pull "$image" >/dev/null || { echo "FAIL: cannot pull $image" >&2; exit 1; }
  done
fi
venv="$(mktemp -d)"
trap 'rm -rf "$venv"' EXIT HUP INT TERM
python3 -m venv "$venv"
"$venv/bin/python" -m pip install --quiet --disable-pip-version-check PyYAML==6.0.3
"$venv/bin/python" -u "${ROOT_DIR}/ci/test-k8s-manifests.py"
