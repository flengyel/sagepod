#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMPOSE_FILE="${SCRIPT_DIR}/podman-compose.yml"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd podman
require_cmd podman-compose

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "Unable to find compose file at ${COMPOSE_FILE}." >&2
  exit 1
fi

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  echo "podman machine requires qemu-system-x86_64 (install with 'sudo apt install qemu-system-x86')." >&2
  exit 1
fi

if ! podman ps >/dev/null 2>&1; then
  if podman machine list --format '{{.Name}}' 2>/dev/null | grep -q '^default$' && podman machine start >/dev/null 2>&1; then
    :
  else
    echo "podman is not running and no podman machine could be started." >&2
    echo "If 'podman machine init' failed previously, remove the broken machine with 'podman machine rm -f default' and re-run 'podman machine init --now'." >&2
    exit 1
  fi
fi

podman-compose -f "${COMPOSE_FILE}" down
