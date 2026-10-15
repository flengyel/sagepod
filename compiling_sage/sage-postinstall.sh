#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

case "${1:-}" in
  -h|--help)
    echo 'Usage: compiling_sage/sage-postinstall.sh'
    echo "Install source-built CryptoMiniSat and Jupyter widgets into native Sage ${SAGE_TAG}."
    echo "SAGE_HOME defaults to ${SAGE_HOME}."
    exit 0 ;;
  '') ;;
  *) die "Unknown argument: $1" ;;
esac
[[ $# -le 1 ]] || die 'Unexpected extra arguments.'
require_native_source

# Check the built environment before changing any of its packages.
"$SAGE_HOME/sage" -python -c \
  'import sys; from sage.env import SAGE_VERSION; assert SAGE_VERSION == sys.argv[1], SAGE_VERSION' "$SAGE_TAG"
"$SAGE_HOME/sage" -pip install --no-user --no-binary=pycryptosat --force-reinstall pycryptosat==5.11.21
# These frontend generations match the validated SagePod 10.10 environment.
"$SAGE_HOME/sage" -pip install --no-user \
  'notebook>=7,<8' 'jupyterlab>=4,<5' 'ipywidgets>=8,<9' 'jupyterlab_widgets>=3,<4'
"$SAGE_HOME/sage" -python - <<'PYTHON'
from importlib.metadata import version
import sage.all
from sage.repl.ipython_kernel.install import SageKernelSpec
from sage.sat.solvers.cryptominisat import CryptoMiniSat

SageKernelSpec.update()
solver = CryptoMiniSat()
solver.add_clause((1,))
assert solver()[1] is True
solver.add_clause((-1,))
assert solver() is False
assert version('pycryptosat') == '5.11.21'
print('Native Sage CryptoMiniSat SAT/UNSAT passed; pycryptosat', version('pycryptosat'))
print('Widgets:', version('ipywidgets'), 'JupyterLab widgets:', version('jupyterlab_widgets'))
PYTHON
