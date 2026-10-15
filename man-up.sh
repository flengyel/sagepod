#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/bin/common.sh"

usage() {
  cat <<'USAGE'
Usage: ./man-up.sh [--no-follow | --follow] [--open]

Start SagePod, check Sage and its mounts, and print the Jupyter URL.
  --no-follow, -n  Return after startup checks.
  --follow, -f     Follow container logs (the default); Ctrl-C stops following.
  --open, -o       Open the configured URL in the Windows browser when available.

Environment: SAGE_TAG=10.8, PORT=8889, CONTAINER_NAME=sagepod,
             SAGEPOD_NETWORK_MODE=slirp4netns
USAGE
}
FOLLOW=1
OPEN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-follow|-n) FOLLOW=0 ;;
    --follow|-f) FOLLOW=1 ;;
    --open|-o) OPEN=1 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

require_rootless_podman
find_compose
mkdir -p -- "${MOUNT_DIRS[@]}"
ensure_image
compose up -d
"${SAGEPOD_ROOT}/bin/verify.sh"

printf '\nJupyter: http://localhost:%s\n' "$PORT"
# Jupyter writes its startup URL to stderr; include both log streams.
TOKEN="$(podman logs --tail 2000 "$CONTAINER_NAME" 2>&1 | grep -Eo 'token=[0-9a-f]+' | tail -n 1 || true)"
if [[ -n "$TOKEN" ]]; then
  printf 'URL with token: http://localhost:%s/tree?%s\n' "$PORT" "$TOKEN"
else
  printf 'The token may appear shortly. Run: podman logs --tail 2000 %s\n' "$CONTAINER_NAME"
fi
if [[ "$OPEN" == 1 ]] && command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -Command "Start-Process 'http://localhost:${PORT}'" >/dev/null 2>&1 || true
fi
if [[ "$FOLLOW" == 1 ]]; then
  exec podman logs -f "$CONTAINER_NAME"
fi
