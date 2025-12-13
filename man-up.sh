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

ensure_podman_machine() {
  if podman ps >/dev/null 2>&1; then
    return
  fi

  if podman machine list --format '{{.Name}}' 2>/dev/null | grep -q '^default$'; then
    if podman machine start >/dev/null 2>&1; then
      return
    fi

    echo "Podman machine 'default' exists but failed to start." >&2
    echo "If a previous 'podman machine init' failed, try removing it with 'podman machine rm -f default' and re-run 'podman machine init --now'." >&2
  else
    echo "No Podman machine found. Run 'podman machine init --now' (requires qemu-system-x86_64) and retry." >&2
  fi

  exit 1
}

ensure_podman_machine

mkdir -p "$HOME/Jupyter" "$HOME/.jupyter"

podman-compose -f "${COMPOSE_FILE}" up -d
podman logs -f sagemath
