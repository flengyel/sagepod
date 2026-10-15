# Native Sage 10.10 build helpers

These optional helpers configure a native Sage 10.10 source build on Debian or
Ubuntu and install source-built CryptoMiniSat and Jupyter widgets afterward.
SagePod's container installation uses `bin/setup.sh`; the native workflow is
separate.

The helpers follow the
[Sage 10.10 source-build instructions](https://github.com/sagemath/sage/blob/10.10/README.md#instructions-to-build-from-source).
The source build needs an external Python version supported by Sage 10.10
(3.12, 3.13, or 3.14), including its development headers and virtual-environment
support. Source and installation paths must be absolute and contain no whitespace.

## Build

Run as the normal Linux user. Prepare the Sage 10.10 source tree:

```bash
mkdir -p ~/sage
git clone --branch 10.10 --depth 1 https://github.com/sagemath/sage.git ~/sage/sage-10.10
```

Alternatively, extract the full `sage-10.10.tar.gz` distribution at that path.
The [archive URL](mirror_list) points to the official release. The smaller
`sagemath-10.10.tar.gz` library archive does not supply this complete build tree.

From the SagePod checkout, inspect the prerequisite commands, install the
prerequisites, configure Sage, build it, and run post-installation checks:

```bash
./compiling_sage/sage-prereq.sh --dry-run
./compiling_sage/sage-prereq.sh
./compiling_sage/minimal_sage.sh
make -C ~/sage/sage-10.10 -j4
./compiling_sage/sage-postinstall.sh
~/sage/sage-10.10/sage --version
```

The prerequisite helper reads the selected release's `_prereq` and `_bootstrap`
Debian package metadata and adds Git and a Fortran compiler. It uses `sudo` for
the apt commands. Sage's configure output identifies additional system libraries
that can reduce the amount compiled from source.

The configure helper runs `make configure`, then `./configure` in the source
tree. It forwards any arguments to `./configure`. The post-installation helper
checks the built Sage version, compiles `pycryptosat==5.11.21` from source,
installs Notebook 7, JupyterLab 4, ipywidgets 8, and JupyterLab widgets 3 in Sage's
Python environment, registers the Sage kernel, and tests CryptoMiniSat SAT/UNSAT
behavior. The frontend packages supply the widget extensions.

## Configuration and validation

| Variable | Default | Meaning |
| --- | --- | --- |
| `SAGE_TAG` | `10.10` | Expected Sage source and runtime version; shared with the container helpers. |
| `SAGE_HOME` | `~/sage/sage-10.10` | Extracted or cloned full Sage source tree. |
| `SAGE_LOCAL` | `$SAGE_HOME/local` | Native installation prefix passed to configure. |

Set the same overrides for every native helper and use the corresponding path
for the `make` and `sage` commands. Each helper supports `--help`.

Host-side tests exercise command routing, version checks, and failure handling
with substituted build and package commands. The prerequisite dry run is also
checked against the real Sage 10.10 source metadata. The container build and live
solver validation are recorded in [the setup review](../docs/setup-review.md).
A complete native host compilation has not been run for this helper update.
