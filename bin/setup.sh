#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

case "${1:-}" in
  -h|--help)
    echo 'Usage: bin/setup.sh'
    echo 'Prepare the mounts and local tools, build the missing image, and start SagePod.'
    exit 0 ;;
  '') ;;
  *) die "Unknown argument: $1" ;;
esac
[[ $# -le 1 ]] || die 'Unexpected extra arguments.'

require_rootless_podman
require_cmd python3
require_cmd setfacl

"${SAGEPOD_ROOT}/bin/fix-bind-mounts.sh"
if [[ ! -x "${SAGEPOD_ROOT}/.venv/bin/podman-compose" ]] ||
   ! "${SAGEPOD_ROOT}/.venv/bin/python" -m pip check >/dev/null 2>&1 ||
   ! "${SAGEPOD_ROOT}/.venv/bin/podman-compose" --dry-run --version >/dev/null 2>&1; then
  "${SAGEPOD_ROOT}/bin/venvfix.sh"
fi
"${SAGEPOD_ROOT}/man-up.sh" --no-follow
echo 'Setup complete. Run ./man-down.sh to stop SagePod.'
