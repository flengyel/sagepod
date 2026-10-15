# Setup provenance

The standalone setup incorporates the bootstrap and image-building approach from
[`flengyel/sagequeue`](https://github.com/flengyel/sagequeue) at commit
[`80140ea1d2d0053b8015dc9092812fabd0c0e053`](https://github.com/flengyel/sagequeue/tree/80140ea1d2d0053b8015dc9092812fabd0c0e053).
The SagePod starting point was
[`3c70e9b7aa7db49c1bc7434b0d11c8b4451ba597`](https://github.com/flengyel/sagepod/tree/3c70e9b7aa7db49c1bc7434b0d11c8b4451ba597).
Both repositories carry the same MIT license and copyright notice, retained in
`LICENSE`.

The current SagePod release uses Sage 10.10 on Debian Trixie with source-built
`pycryptosat==5.11.21`. See the [validation record](setup-review.md) for the
upgrade from the earlier Bullseye-based Sage 10.8 image.

| SageQueue source | SagePod adaptation |
| --- | --- |
| `Containerfile` | Use Sage 10.10 on Debian Trixie after compatibility validation; retain the build dependencies and source-built `pycryptosat==5.11.21`; install outside the mounted home and test Sage's solver interface. |
| `bin/setup.sh` | Prepare SagePod mounts and `.venv`, build a missing image, start Jupyter, and check mounts and solver operation. |
| `bin/build-image.sh` | Build `localhost/sagepod-sagemath`; leave existing containers running until explicitly stopped. |
| `bin/venvfix.sh` | Keep the environment under `.venv`; retain SagePod's pinned requirements and optional interpreter argument. |
| `bin/fix-bind-mounts.sh` | Cover all six SagePod mounts; use rootless ownership changes and ACLs instead of creating host accounts; retain executable bits. |
| `bin/show-mapped-ids.sh` | Incorporate argument validation and mapping diagnostics. |
| `man-up.sh` and Compose configuration | Build before startup when the local image is absent; use SagePod's paths, port, and container name consistently. |

The setup does not import the queue worker, recovery services, jobset configurations,
progress monitor, or experiment scripts. Those components are not prerequisites
for SagePod's interactive Sage/Jupyter environment. No workload-specific file,
SageQueue checkout, or SageQueue image is needed by the new setup.

The upstream DOT_SAGE seeding step is replaced by an image-build check: the installed
`pycryptosat` module must lie outside `/home/sage`. A base-image change that violates
this condition fails the build instead of silently relying on packages copied into
host state. Installation runs as root inside the image build because the base
image's Sage environment is root-owned. The module-location and solver checks run
as runtime user `1000:1000`. The runtime check exercises the solver with all mounts
attached.

Sage's Jupyter kernelspec is also registered in Sage's environment during the
image build. A check as `1000:1000` requires it to be discoverable outside
`/home/sage`. This supplies a Sage kernel when `.sagepod-local` is initially empty.

The original SagePod `.sagepod-local` mount remains attached to `/home/sage/.local`.
It has not been moved to `/home/sage/.local/share`, which would reinterpret existing
host data. Shared notebook and Jupyter configuration mounts use the shared SELinux
label option `z`; SagePod-specific mounts retain `Z`. See the
[Podman volume documentation](https://docs.podman.io/en/latest/markdown/podman-run.1.html).

The obsolete tracked `pyvenv.cfg` is removed. Top-level compatibility wrappers retain
existing command names, and the venv repair replaces only `.venv`. Legacy in-place
venv files are not automatically removed.

The optional [native source-build helpers](../compiling_sage/README.md) share
the Sage 10.10 default. Their prerequisite package names come from that Sage
release's metadata, and their post-installation step uses the same source-built
`pycryptosat` pin as the container. Their native-build scope is separate from
the incorporated SageQueue container setup.
