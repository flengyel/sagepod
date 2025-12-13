#!/bin/bash

set -euo pipefail

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  echo "podman machine requires qemu-system-x86_64 (install with 'sudo apt install qemu-system-x86')." >&2
  exit 1
fi

ensure_podman_machine() {
  if podman ps >/dev/null 2>&1; then
    return
  fi

  # Start the default podman machine when running in environments like WSL2.
  if podman machine start >/dev/null 2>&1; then
    return
  fi

  echo "podman is not running and no podman machine could be started." >&2
  echo "Please run 'podman machine init' and try again." >&2
  exit 1
}

ensure_podman_machine

podman-compose -f ~/sagepod/podman-compose.yml up -d
podman logs -f sagemath
