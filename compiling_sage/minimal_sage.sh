#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

case "${1:-}" in
  -h|--help)
    echo 'Usage: compiling_sage/minimal_sage.sh [configure-options...]'
    echo "Configure Sage ${SAGE_TAG} in SAGE_HOME=${SAGE_HOME}."
    echo "The default installation prefix is SAGE_LOCAL=${SAGE_LOCAL}."
    exit 0 ;;
esac
require_native_source
require_cmd make

cd "$SAGE_HOME"
make configure
./configure "--prefix=$SAGE_LOCAL" "$@"
printf 'Configured Sage %s. Build with: make -C %q -j4\n' "$SAGE_TAG" "$SAGE_HOME"
