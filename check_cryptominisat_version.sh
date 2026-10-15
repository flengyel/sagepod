#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/bin/common.sh"
require_cmd podman
podman exec "$CONTAINER_NAME" /sage/sage --version
podman exec "$CONTAINER_NAME" /sage/sage -python -c \
  'from importlib.metadata import version; import pycryptosat; print("pycryptosat", version("pycryptosat")); print(pycryptosat.__file__)'
