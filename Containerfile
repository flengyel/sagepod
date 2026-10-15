# Adapted from flengyel/sagequeue; see docs/setup-provenance.md.
ARG SAGE_TAG=10.8
FROM ghcr.io/sagemath/sage/sage-debian-bullseye-standard-with-targets-optional:${SAGE_TAG}

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      make gcc g++ cmake pkg-config \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /home/sage /sage && chown 1000:1000 /home/sage /sage
ENV HOME=/home/sage
ENV DOT_SAGE=/home/sage/.sage

WORKDIR /sage
RUN if [ ! -x /sage/sage ]; then \
      if command -v sage >/dev/null 2>&1; then \
        ln -s "$(command -v sage)" /sage/sage; \
      else \
        echo 'Sage is missing from the base image' >&2; exit 1; \
      fi; \
    fi

# The base image's Sage environment is not writable by runtime user 1000.
# Install as image root, outside the bind-mounted home, then test as that user.
RUN ./sage -pip install --no-user --no-binary=pycryptosat --force-reinstall pycryptosat==5.11.21
# Register in Sage's environment so an empty .local mount still has a Sage kernel.
RUN ./sage -python -c "from sage.repl.ipython_kernel.install import SageKernelSpec; SageKernelSpec.update()"
USER 1000:1000
RUN ./sage -python -c "from pathlib import Path; import pycryptosat; \
    assert not Path(pycryptosat.__file__).resolve().is_relative_to('/home/sage'), 'pycryptosat would be hidden by the home mounts'"
RUN ./sage -python -c "from pathlib import Path; from jupyter_client.kernelspec import KernelSpecManager; \
    spec=KernelSpecManager().get_kernel_spec('sagemath'); assert spec.language == 'sage'; \
    assert not Path(spec.resource_dir).resolve().is_relative_to('/home/sage'), 'Sage kernel would be hidden by the home mounts'"
RUN ./sage -python -c "import sage.all; from sage.sat.solvers.cryptominisat import CryptoMiniSat; \
    s=CryptoMiniSat(); s.add_clause((1,)); assert s()[1] is True; \
    s.add_clause((-1,)); assert s() is False"

