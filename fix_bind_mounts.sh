#!/usr/bin/env bash
set -euo pipefail
# Compatibility entry point for existing SagePod checkouts.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin/fix-bind-mounts.sh" "$@"
