#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/bin/common.sh"
require_cmd podman
exec podman exec -it "$CONTAINER_NAME" /bin/bash "$@"
