#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
  echo 'Usage: bin/venvfix.sh [python-executable]'
  echo 'Rebuild only the .venv directory in this repository.'
}
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  -*) usage >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { usage >&2; exit 2; }
SAGEPOD_PYTHON="${1:-python3}"
require_cmd "$SAGEPOD_PYTHON"

# Never remove bin/: it contains tracked setup scripts, not a virtual environment.
rm -rf -- "${SAGEPOD_ROOT}/.venv"
"$SAGEPOD_PYTHON" -m venv "${SAGEPOD_ROOT}/.venv"
VENV_PY="${SAGEPOD_ROOT}/.venv/bin/python"
"$VENV_PY" -m pip --version >/dev/null || die 'pip is missing; install python3-venv on the host.'
"$VENV_PY" -m pip install -r "${SAGEPOD_ROOT}/requirements.txt"
"$VENV_PY" -m pip check
"${SAGEPOD_ROOT}/.venv/bin/podman-compose" --dry-run --version
echo "Created ${SAGEPOD_ROOT}/.venv. Activation is not required."
