#!/usr/bin/env bash
# Shared paths and defaults for the SagePod commands. Source this file from Bash.

SAGEPOD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${SAGEPOD_ROOT}/podman-compose.yml"
export SAGE_TAG="${SAGE_TAG:-10.8}"
export CONTAINER_NAME="${CONTAINER_NAME:-sagepod}"
export PORT="${PORT:-8889}"
export SAGEPOD_NETWORK_MODE="${SAGEPOD_NETWORK_MODE:-slirp4netns}"
IMAGE="localhost/sagepod-sagemath:${SAGE_TAG}-pycryptosat"
# Used by scripts that source this file.
# shellcheck disable=SC2034
MOUNT_DIRS=(
  "$HOME/Jupyter" "$HOME/.jupyter" "$HOME/.sagepod-dot_sage"
  "$HOME/.sagepod-local" "$HOME/.sagepod-config" "$HOME/.sagepod-cache"
)

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

require_rootless_podman() {
  [[ "$(id -u)" != 0 ]] || die "Run as the normal Linux user, without sudo."
  require_cmd podman
  podman ps >/dev/null || die "Podman is unavailable. Check the rootless Podman and WSL prerequisites in README.md."
}

find_compose() {
  if [[ -x "${SAGEPOD_ROOT}/.venv/bin/podman-compose" ]]; then
    PODMAN_COMPOSE="${SAGEPOD_ROOT}/.venv/bin/podman-compose"
  elif command -v podman-compose >/dev/null 2>&1; then
    PODMAN_COMPOSE="$(command -v podman-compose)"
  else
    die "podman-compose is missing. Run ${SAGEPOD_ROOT}/bin/venvfix.sh."
  fi
}

compose() (
  cd "$SAGEPOD_ROOT" || exit 1
  "$PODMAN_COMPOSE" -p sagepod -f "$COMPOSE_FILE" "$@"
)

ensure_image() {
  if ! podman image exists "$IMAGE"; then
    "${SAGEPOD_ROOT}/bin/build-image.sh"
  fi
}
