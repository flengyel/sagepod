#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

case "${1:-}" in
  -h|--help)
    echo 'Usage: bin/verify.sh'
    echo 'Check Sage, CryptoMiniSat, and writable mounts in the running SagePod container.'
    exit 0 ;;
  '') ;;
  *) die "Unknown argument: $1" ;;
esac
[[ $# -le 1 ]] || die 'Unexpected extra arguments.'
require_cmd podman

podman exec -i "$CONTAINER_NAME" /sage/sage -python - <<'PYTHON'
from importlib.metadata import version
from pathlib import Path
from tempfile import TemporaryFile

from sage.all import factor
from sage.sat.solvers.cryptominisat import CryptoMiniSat
import pycryptosat

print("factor(1023) =", factor(1023))
solver = CryptoMiniSat()
solver.add_clause((1,))
assert solver()[1] is True, "CryptoMiniSat failed the satisfiable example"
solver.add_clause((-1,))
assert solver() is False, "CryptoMiniSat failed the unsatisfiable example"
print("pycryptosat", version("pycryptosat"), "at", pycryptosat.__file__)

for relative in ("notebooks", ".jupyter", ".sage", ".local", ".config", ".cache"):
    directory = Path("/home/sage") / relative
    with TemporaryFile(dir=directory) as probe:
        probe.write(b"sagepod mount check\n")
        probe.flush()
    print("Writable:", directory)
print("SagePod checks passed.")
PYTHON
