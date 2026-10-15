#!/usr/bin/env bash
set -euo pipefail
# Compatibility entry point; the environment now lives only in .venv/.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin/venvfix.sh" "$@"
