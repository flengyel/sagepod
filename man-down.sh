#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/bin/common.sh"

case "${1:-}" in
  -h|--help)
    echo 'Usage: ./man-down.sh'
    echo 'Stop and remove the SagePod container; keep the image and host data.'
    exit 0 ;;
  '') ;;
  *) die "Unknown argument: $1" ;;
esac
[[ $# -le 1 ]] || die 'Unexpected extra arguments.'
require_rootless_podman
find_compose
compose down
