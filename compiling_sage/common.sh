#!/usr/bin/env bash
# Shared defaults for the optional native source-build helpers.
source "$(dirname "${BASH_SOURCE[0]}")/../bin/common.sh"
export SAGE_HOME="${SAGE_HOME:-$HOME/sage/sage-$SAGE_TAG}"
export SAGE_LOCAL="${SAGE_LOCAL:-$SAGE_HOME/local}"

require_native_source() {
  [[ "$SAGE_HOME" != *[[:space:]]* && "$SAGE_LOCAL" != *[[:space:]]* ]] ||
    die 'Sage source and installation paths must contain no whitespace.'
  [[ "$SAGE_HOME" == /* && "$SAGE_LOCAL" == /* ]] ||
    die 'Set SAGE_HOME and SAGE_LOCAL to absolute paths.'
  [[ -f "$SAGE_HOME/VERSION.txt" && -x "$SAGE_HOME/sage" && -x "$SAGE_HOME/configure" ]] ||
    die "Extract the full Sage ${SAGE_TAG} source distribution at ${SAGE_HOME}, or set SAGE_HOME."
  local native_version
  native_version="$(cat "$SAGE_HOME/VERSION.txt")"
  [[ "$native_version" == "$SAGE_TAG" ]] ||
    die "Source version ${native_version} does not match SAGE_TAG=${SAGE_TAG}."
}
