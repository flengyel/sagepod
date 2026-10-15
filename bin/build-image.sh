#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo 'Usage: bin/build-image.sh [--sage-tag VERSION]'
  echo 'Build the SagePod image. Running containers are left in place.'
  echo 'SAGE_TAG defaults to 10.8; --sage-tag overrides it for this build.'
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sage-tag)
      [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || { usage >&2; exit 2; }
      export SAGE_TAG="$2"
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_rootless_podman

echo "Building ${IMAGE}"
podman build --network "$SAGEPOD_NETWORK_MODE" \
  -f "${SAGEPOD_ROOT}/Containerfile" --build-arg "SAGE_TAG=${SAGE_TAG}" \
  -t "$IMAGE" "$SAGEPOD_ROOT"
echo "Built ${IMAGE}. Stop and start SagePod to use the rebuilt image."
