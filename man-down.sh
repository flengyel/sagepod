#!/bin/bash

set -euo pipefail

if ! podman ps >/dev/null 2>&1; then
  if ! podman machine start >/dev/null 2>&1; then
    echo "podman is not running and no podman machine could be started." >&2
    echo "Please run 'podman machine init' and try again." >&2
    exit 1
  fi
fi

podman-compose -f ~/sagepod/podman-compose.yml down
