# SagePod

SagePod runs SageMath and Jupyter in a rootless Podman container on Linux or
WSL2. This repository contains the setup scripts and image definition, including
CryptoMiniSat support through `pycryptosat`; no SageQueue checkout or image is
required. Installation downloads the base image and packages from their upstream
registries.

The defaults are Sage 10.10, container `sagepod`, and Jupyter at
<http://localhost:8889>. Notebooks remain in `~/Jupyter` when the container stops.
Sage 10.10 uses the upstream Debian Trixie image. See the
[validation record](docs/setup-review.md) for container, solver, Jupyter, and
persistence checks with this setup.

The image build starts with upstream's prebuilt Sage and compiles CryptoMiniSat
support from source inside the container image. The host Python environment runs
Compose; Sage and its compiler toolchain are supplied by the container image.

## Prerequisites

Run the commands below in Debian or Ubuntu as the normal Linux user. Use `sudo`
only for installing host packages and editing system configuration.

```bash
sudo apt update
sudo apt install -y git podman slirp4netns uidmap acl python3-venv
```

The recorded validation used Debian 13 under WSL2 on x86-64 (`linux/amd64`)
with Podman 5.4.2. The base image download was about 4 GiB compressed; allow
additional disk space for its unpacked layers and the SagePod image. Other hosts
and architectures were outside those validation runs.

Keep the checkout and data in the Linux filesystem, such as `~/src/sagepod` and
`~/Jupyter`. The permission setup requires Unix ownership and access-control lists
(ACLs); a Windows drive mounted under `/mnt/c` may not provide these semantics.

### WSL2

Use a WSL version that supports systemd (0.67.6 or newer). Enable systemd in
`/etc/wsl.conf`, preserving any existing sections, as described in
[Microsoft's WSL systemd instructions](https://learn.microsoft.com/en-us/windows/wsl/systemd):

```ini
[boot]
systemd=true
```

From Windows PowerShell, shut down WSL and reopen the distribution:

```powershell
wsl.exe --shutdown
```

### Check rootless Podman

On Linux or WSL2, check Podman from the Linux shell:

```bash
podman ps
podman unshare cat /proc/self/uid_map /proc/self/gid_map
```

Both commands must succeed without `sudo`. The namespace mappings must include
container user and group 1000. SagePod uses manual start and stop commands; it
does not install queue services or enable user lingering.

## Install

Clone SagePod and run its setup:

```bash
mkdir -p ~/src
git clone https://github.com/flengyel/sagepod.git ~/src/sagepod
cd ~/src/sagepod
bin/setup.sh
```

Setup creates the six data directories listed below, repairs their permissions,
installs the pinned Compose dependencies in `.venv`, builds the SagePod image if
missing, and starts Jupyter. It then checks Sage's CryptoMiniSat backend and writes
a temporary file in each container mount. It does not require an experiment script
or copy notebooks into the data directories.

Setup can be rerun. An existing image and usable `.venv` are reused. Rerunning
setup repairs permissions again; configuration changes can also recreate the
container. The permission step changes ownership and ACLs recursively in the six
data directories; file contents and existing executable bits are preserved. Save
active notebook work before rerunning setup or repairing permissions.

Open the printed URL at <http://localhost:8889>. If the token has not appeared yet:

```bash
podman logs --tail 2000 "${CONTAINER_NAME:-sagepod}"
```

Use the token from the Jupyter log with host port **8889**; port 8888 in the log
is the port inside the container.

To check the installation, run:

```bash
./check_cryptominisat_version.sh
bin/verify.sh
```

The default image reports Sage 10.10, Python 3.13.5, and pycryptosat 5.11.21.
In Jupyter, create a notebook using the **SageMath** kernel and run:

```python
from sage.env import SAGE_VERSION
print(SAGE_VERSION)
factor(2^10 - 1)
```

The version should be `10.10`, and the factorization should be `3 * 11 * 31`.
This verifies Sage execution in the notebook. The command-line checks also test
CryptoMiniSat and mount access.

## Start and stop

Run these commands from the checkout. The scripts also work by absolute path from
another directory.

| Command | Action |
| --- | --- |
| `./man-up.sh --no-follow` | Start Jupyter, run checks, and print its URL. Build the image if it is missing. |
| `./man-up.sh` | Start and check Jupyter, then follow logs. Ctrl-C stops following logs; the container keeps running. |
| `./man-up.sh --no-follow --open` | Also open the URL in the Windows browser, when PowerShell is available. |
| `./man-down.sh` | Stop and remove the container; retain the image and host data. |
| `./run-bash.sh` | Open a shell in the running SagePod container. |
| `bin/verify.sh` | Report Sage/Python/solver versions and check all six container mounts and the solver. |
| `./check_cryptominisat_version.sh` | Print Sage, Python, and `pycryptosat` versions from the container. |

Save notebook work before stopping or recreating the container. Files in the bind
mounts persist; running kernels and unsaved in-memory results do not.

## Configuration

Set overrides in the shell before running the helpers. The same values are passed
to the image builder, Compose, and container checks.

| Variable | Default | Meaning |
| --- | --- | --- |
| `SAGE_TAG` | `10.10` | Base-image tag and local-image version. |
| `PORT` | `8889` | Host port mapped to Jupyter's container port 8888. |
| `CONTAINER_NAME` | `sagepod` | Container name used by every helper. |
| `SAGEPOD_NETWORK_MODE` | `slirp4netns` | Podman network mode for builds and the running container. |

Save notebook work before changing configuration: the next startup can recreate
the container. For example:

```bash
export PORT=8890
./man-up.sh --no-follow
```

Keep the same overrides for later start, stop, and diagnostic commands. The
helpers use Compose project `sagepod` and the same six data paths even when a
custom container name or port is selected. A custom name alone does not create
an independent installation.

The helpers prefer `.venv/bin/podman-compose`, with a fallback to `podman-compose`
on `PATH`. Setup creates the repository's own `.venv` when one is missing or
unusable. Run `bin/venvfix.sh` to reinstall the pinned requirements after they
change; a usable existing environment is otherwise reused.

Use a port number for `PORT`. The default Compose entry, `${PORT:-8889}:8888`,
publishes Jupyter on all host interfaces, subject to host/WSL networking and
firewall settings. To bind only to the host's loopback interface, change the
entry under `ports` in `podman-compose.yml` to:

```yaml
      - "127.0.0.1:${PORT:-8889}:8888"
```

Apply the change with `./man-down.sh` followed by `./man-up.sh --no-follow`. See
[Podman's port-publishing documentation](https://docs.podman.io/en/latest/markdown/podman-run.1.html).

The local image is `localhost/sagepod-sagemath:10.10-pycryptosat`, or the corresponding
tag when `SAGE_TAG` is set. During the image build, `Containerfile` compiles
CryptoMiniSat support through `pycryptosat==5.11.21` from source in Sage's Python
environment, using `--no-binary=pycryptosat`. The compiled package is installed
in the image outside `/home/sage`, where bind mounts could hide it. Build checks
run satisfiable and unsatisfiable examples through Sage's CryptoMiniSat interface
as runtime user `1000:1000`.
The image registers the Sage Jupyter kernel outside `/home/sage` and checks its
discovery as the runtime user, so fresh data mounts still provide a Sage kernel.

## Persistent data

A bind mount makes a host directory available at a path inside the container.

| Host directory | Container directory |
| --- | --- |
| `~/Jupyter` | `/home/sage/notebooks` |
| `~/.jupyter` | `/home/sage/.jupyter` |
| `~/.sagepod-dot_sage` | `/home/sage/.sage` |
| `~/.sagepod-local` | `/home/sage/.local` |
| `~/.sagepod-config` | `/home/sage/.config` |
| `~/.sagepod-cache` | `/home/sage/.cache` |

The container runs as user and group `1000:1000` in Podman's user namespace.
`bin/fix-bind-mounts.sh` adjusts ownership within that namespace and gives the host
user access through ACLs, including defaults inherited by new files. It requires
no host `sage` account or group. `bin/show-mapped-ids.sh` prints the corresponding
host IDs.

Files saved in these six paths survive container removal. Changes elsewhere in
the container's writable filesystem are discarded when the container is removed.
Back up the host data directories separately when you need a recoverable copy.

## Rebuild or repair

Rebuild the image after changing `Containerfile`:

```bash
bin/build-image.sh &&
  ./man-down.sh &&
  ./man-up.sh --no-follow
```

Building alone leaves the running container in place. Stop and start it to use the
new image. A failed build therefore does not remove a working container. For a
different Sage version, export `SAGE_TAG` before the sequence above. The optional
`bin/build-image.sh --sage-tag VERSION` selects only that build's version; export
the same value before starting it. The selected tag must exist in the upstream
Debian Trixie image repository. Other base-image versions require validation.

To upgrade an existing Sage 10.8 installation, save notebook work and back up the
host data directories. Then update the checkout and select 10.10 explicitly so
an older exported `SAGE_TAG` cannot select the old image:

```bash
cd ~/src/sagepod &&
  git pull --ff-only &&
  export SAGE_TAG=10.10 &&
  bin/build-image.sh &&
  ./man-down.sh &&
  ./man-up.sh --no-follow &&
  ./check_cryptominisat_version.sh
```

Retain any custom `PORT` and `CONTAINER_NAME` values throughout the upgrade.
The six data paths stay the same. To roll back, first check that
`localhost/sagepod-sagemath:10.8-pycryptosat` is present with `podman image exists`.
Then stop SagePod and start it with `SAGE_TAG=10.8 ./man-up.sh --no-follow`.
Retain that override for subsequent commands. Building Sage 10.8 with the new
Trixie base has not been validated.

Rebuild the local Python environment:

```bash
bin/venvfix.sh
```

Only `.venv` is replaced. The old `./venvfix.sh` command remains as a wrapper;
it no longer deletes `bin`, `lib`, or other checkout contents. No virtual-environment
activation is required.

Repair mount permissions and verify them:

```bash
bin/fix-bind-mounts.sh
bin/verify.sh
```

The old `./fix_bind_mounts.sh` and `./show-mapped-ids.sh` names remain available.

## Update an installation that used SageQueue

Save active notebook work and stop the old SagePod container before updating the
checkout. After updating, run:

```bash
cd ~/src/sagepod
export SAGE_TAG=10.10
bin/setup.sh
```

SagePod builds its own image and retains the existing data paths and host port.
The `sagemath` container, SageQueue image, queue services, and SageQueue state are
not managed by these scripts. `~/Jupyter` and `~/.jupyter` remain shared if SageQueue
also mounts them; the four `.sagepod-*` directories remain specific to SagePod.
Do not delete the old shared image while SageQueue still needs it.

## Troubleshooting

### Podman cannot run as the normal user

Check the WSL systemd setting and the UID/GID maps shown under Prerequisites.
If mappings are missing, configure subordinate IDs in `/etc/subuid` and
`/etc/subgid` using the distribution's rootless Podman instructions. The
[Podman rootless guide](https://github.com/podman-container-tools/podman/blob/main/docs/tutorials/rootless_tutorial.md)
explains these prerequisites.

For a WSL installation with cgroup or event-logging errors, merge the following
settings into `~/.config/containers/containers.conf`; preserve unrelated settings:

```ini
[engine]
cgroup_manager="cgroupfs"
events_logger="file"

[network]
default_rootless_network_cmd="slirp4netns"
```

### `podman-compose` is missing or broken

Run `bin/venvfix.sh`, then retry startup. Install `python3-venv` if Python cannot
create the environment. The scripts do not search another repository for Compose.

### `netavark: nftables error`

Check that `SAGEPOD_NETWORK_MODE` has not overridden `slirp4netns` and that the host
package `slirp4netns` is installed. Retry with:

```bash
SAGEPOD_NETWORK_MODE=slirp4netns ./man-up.sh --no-follow
```

### Pulling or building the image fails

The first build needs access to `ghcr.io`, the base image's Debian repositories,
and PyPI. Check the reported registry or package error before retrying
`bin/build-image.sh`. For a certificate error, check the host's trust configuration
and any TLS-inspection proxy; do not disable certificate verification.

### A mount is not writable

Run `bin/fix-bind-mounts.sh` as the normal Linux user, then `bin/verify.sh`.
If ACL operations report that they are unsupported, move the data to a Linux
filesystem with ACL support. Existing files owned by IDs outside the rootless
namespace may require an administrator to correct their ownership first.

### Sage works but Jupyter is not reachable

Check the running container and its startup log:

```bash
podman ps
podman logs --tail 2000 "${CONTAINER_NAME:-sagepod}"
```

Verify that the host port is free and use the configured host port in the browser.
Jupyter may still be starting when `man-up.sh --no-follow` returns.
`bin/verify.sh` checks Sage and filesystem access; it is not an HTTP readiness
check for Jupyter.

## Repository contents

| Path | Purpose |
| --- | --- |
| `Containerfile`, `podman-compose.yml` | Build and run the SagePod image. |
| `bin/setup.sh` | Prepare the installation and start it. |
| `bin/build-image.sh`, `bin/venvfix.sh` | Build the image and host Python environment. |
| `bin/fix-bind-mounts.sh`, `bin/show-mapped-ids.sh` | Manage and inspect rootless mount permissions. |
| `bin/verify.sh`, top-level helpers | Start, stop, and check the container. |
| `tests/` | Host-side regression tests, without a Sage image. |
| [`compiling_sage/`](compiling_sage/README.md) | Separate native Sage 10.10 source-build helpers and instructions. |
| [Setup provenance](docs/setup-provenance.md) | Sources and changes made when incorporating SageQueue's setup. |

After setup, run the host-side checks in the repository's Python environment:

```bash
.venv/bin/python -m unittest discover -s tests -v
```

These checks use command substitutes for Podman and native build/package commands.
With `setfacl` installed, they also exercise inherited ACLs on temporary files.
Using `.venv/bin/python` includes the real pinned Compose rendering check. To run
the checks before building an image, create `.venv` with `bin/venvfix.sh` first.
A complete container installation check requires `bin/setup.sh` on a supported
rootless Podman host, followed by opening Jupyter and evaluating a Sage notebook
cell.

## License

MIT. The incorporated SageQueue code has the same author and license; see
[LICENSE](LICENSE).
