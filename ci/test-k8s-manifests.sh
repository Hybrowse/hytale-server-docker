#!/bin/sh
set -eu

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*" >&2
}

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHART_DIR="${ROOT_DIR}/deploy/helm/hytale-server"
KUSTOMIZE_DIR="${ROOT_DIR}/deploy/kustomize"

HELM_IMAGE="alpine/helm:4.0.5"
KUSTOMIZE_IMAGE="registry.k8s.io/kustomize/kustomize:v5.8.0"
KUBECONFORM_IMAGE="ghcr.io/yannh/kubeconform:v0.7.0"
K8S_VERSION="1.35.0"

pull_image() {
  image="$1"
  pull_err="$(docker pull "${image}" >/dev/null 2>&1 || true)"
  if [ -n "${pull_err}" ]; then
    echo "${pull_err}" >&2
    case "${image}" in
      ghcr.io/*)
        if printf '%s' "${pull_err}" | grep -q "denied: denied"; then
          echo "HINT: GHCR returned 'denied' while pulling ${image}." >&2
          echo "HINT: If this repo is public, local GHCR credentials can still cause this." >&2
          echo "HINT: Try: docker logout ghcr.io" >&2
          echo "HINT: Or set KUBECONFORM_IMAGE to an internally mirrored image." >&2
        fi
        ;;
    esac
    fail "docker pull failed for image: ${image}"
  fi
}

pull_image "${HELM_IMAGE}"
pull_image "${KUSTOMIZE_IMAGE}"
pull_image "${KUBECONFORM_IMAGE}"

[ -d "${CHART_DIR}" ] || fail "helm chart dir not found: ${CHART_DIR}"
[ -d "${KUSTOMIZE_DIR}" ] || fail "kustomize dir not found: ${KUSTOMIZE_DIR}"

# Helm lint
if ! docker run --rm -v "${ROOT_DIR}:/work" -w /work "${HELM_IMAGE}" lint deploy/helm/hytale-server >/dev/null; then
  fail "helm lint failed"
fi
pass "helm lint"

# Helm template + schema validation
if ! docker run --rm -v "${ROOT_DIR}:/work" -w /work "${HELM_IMAGE}" template test deploy/helm/hytale-server |
  docker run --rm -i "${KUBECONFORM_IMAGE}" -strict -summary -kubernetes-version "${K8S_VERSION}" -ignore-missing-schemas; then
  fail "helm template kubeconform failed"
fi
pass "helm template + kubeconform"

# Kustomize builds + schema validation
for p in base overlays/development overlays/production overlays/auto-download overlays/pdb overlays/network-policy; do
  if ! docker run --rm -v "${ROOT_DIR}:/work" -w /work "${KUSTOMIZE_IMAGE}" build "deploy/kustomize/${p}" |
    docker run --rm -i "${KUBECONFORM_IMAGE}" -strict -summary -kubernetes-version "${K8S_VERSION}" -ignore-missing-schemas; then
    fail "kustomize build kubeconform failed: ${p}"
  fi
  pass "kustomize build + kubeconform: ${p}"
done

pass "k8s manifests"
