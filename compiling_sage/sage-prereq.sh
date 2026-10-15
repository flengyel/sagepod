#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

DRY_RUN=0
case "${1:-}" in
  -h|--help)
    echo 'Usage: compiling_sage/sage-prereq.sh [--dry-run]'
    echo "Install Debian/Ubuntu build prerequisites from the Sage ${SAGE_TAG} source metadata."
    echo "SAGE_HOME defaults to ${SAGE_HOME}."
    exit 0 ;;
  --dry-run) DRY_RUN=1 ;;
  '') ;;
  *) die "Unknown argument: $1" ;;
esac
[[ $# -le 1 ]] || die 'Unexpected extra arguments.'
require_native_source
[[ -x "$SAGE_HOME/build/bin/sage-get-system-packages" ]] ||
  die 'The source tree is missing build/bin/sage-get-system-packages.'

# Read the selected release's package names instead of maintaining an old apt list.
package_text="$(cd "$SAGE_HOME" && SAGE_ROOT="$SAGE_HOME" \
  ./build/bin/sage-get-system-packages debian _prereq _bootstrap)"
[[ -n "$package_text" ]] || die 'Sage did not return any prerequisite packages.'
read -r -a native_packages <<< "${package_text//$'\n'/ }"
native_packages+=(git gfortran)

if [[ "$DRY_RUN" == 1 ]]; then
  printf '%q ' sudo apt-get update
  printf '\n'
  printf '%q ' sudo apt-get install -y --no-install-recommends "${native_packages[@]}"
  printf '\n'
else
  require_cmd sudo
  require_cmd apt-get
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends "${native_packages[@]}"
fi

