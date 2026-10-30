#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
  echo 'Usage: bin/jupyter-url.sh [--wait SECONDS]'
  echo 'Print the current localhost login URL without restarting SagePod.'
  echo 'Use the running container port mapping and Jupyter server information.'
  echo 'Wait up to 30 seconds for Jupyter by default; --wait 0 checks once.'
}
WAIT=30
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --wait)
    [[ $# == 2 && "$2" =~ ^[0-9]+$ ]] || { usage >&2; exit 2; }
    WAIT="$2" ;;
  '') [[ $# == 0 ]] || { usage >&2; exit 2; } ;;
  *) usage >&2; exit 2 ;;
esac

require_cmd podman
MAPPINGS="$(podman port "$CONTAINER_NAME" 8888/tcp)"
HOST_PORT=''
while IFS= read -r mapping; do
  [[ -n "$mapping" ]] || continue
  port="${mapping##*:}"
  [[ "$port" =~ ^[0-9]+$ ]] || die 'Cannot read the published Jupyter port.'
  [[ -z "$HOST_PORT" || "$HOST_PORT" == "$port" ]] ||
    die 'Jupyter has multiple published ports; inspect podman port before connecting.'
  HOST_PORT="$port"
done <<< "$MAPPINGS"
[[ -n "$HOST_PORT" ]] || die 'Container port 8888/tcp is not published. Check the running SagePod container.'

podman exec -i "$CONTAINER_NAME" /sage/sage -python - \
  --port "$HOST_PORT" --wait "$WAIT" < "${SAGEPOD_ROOT}/bin/jupyter_url.py"
