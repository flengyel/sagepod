#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMPOSE_FILE="${SCRIPT_DIR}/podman-compose.yml"

mkdir -p "$HOME/Jupyter" "$HOME/.jupyter"

podman-compose -f "${COMPOSE_FILE}" up -d

echo
echo "Open in Windows: http://localhost:8888"
echo "If token auth is on, grab it with:"
echo "  podman logs sagemath | grep -o 'token=[0-9a-f]*' | head -1"

exec podman logs -f sagemath
