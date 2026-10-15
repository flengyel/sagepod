# SagePod

SagePod runs SageMath and Jupyter in a rootless Podman container on Linux or
WSL2. This repository contains the setup scripts and image definition, including
CryptoMiniSat support through `pycryptosat`; no SageQueue checkout or image is
required. Installation downloads the base image and packages from their upstream
registries.

The defaults are Sage 10.7, container `sagepod`, and Jupyter at
<http://localhost:8889>. Notebooks remain in `~/Jupyter` when the container stops.
Sage 10.8 has also passed isolated container, solver, Jupyter, and persistence
checks with this setup; see the [validation record](docs/setup-review.md).

## Prerequisites

Run the commands below in Debian or Ubuntu as the normal Linux user. Use `sudo`
only for installing host packages and editing system configuration.

```bash
sudo apt update
sudo apt install -y git podman slirp4netns uidmap acl python3-venv
```

Keep the checkout and data in the Linux filesystem, such as `~/src/sagepod` and
`~/Jupyter`. The permission setup requires Unix ownership and access-control lists
(ACLs); a Windows drive mounted under `/mnt/c` may not provide these semantics.

### WSL2

Enable systemd in `/etc/wsl.conf`, preserving any existing sections:

```ini
[boot]
systemd=true
```

From Windows PowerShell, shut down WSL and reopen the distribution:

```powershell
wsl.exe --shutdown
```

Check Podman from the Linux shell:

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

Setup can be rerun. An existing image and usable `.venv` are reused. The permission
step changes ownership and ACLs recursively in the six data directories; file
contents and existing executable bits are preserved. Stop active notebook work
before repairing permissions in an existing installation.

Open the printed URL at <http://localhost:8889>. If the token has not appeared yet:

```bash
podman logs --tail 2000 sagepod
```

Use the token from the Jupyter log with host port **8889**; port 8888 in the log
is the port inside the container.

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
| `bin/verify.sh` | Check Sage, the solver, and all six container mounts. |
| `./check_cryptominisat_version.sh` | Print Sage and `pycryptosat` versions from the container. |

Save notebook work before stopping or recreating the container. Files in the bind
mounts persist; running kernels and unsaved in-memory results do not.

## Configuration

Set overrides in the shell before running the helpers. The same values are passed
to the image builder, Compose, and container checks.

| Variable | Default | Meaning |
| --- | --- | --- |
| `SAGE_TAG` | `10.7` | Base-image tag and local-image version. |
| `PORT` | `8889` | Host port mapped to Jupyter's container port 8888. |
| `CONTAINER_NAME` | `sagepod` | Container name used by every helper. |
| `SAGEPOD_NETWORK_MODE` | `slirp4netns` | Podman network mode for builds and the running container. |

For example:

```bash
export PORT=8890
./man-up.sh --no-follow
```

Keep the same overrides for later start, stop, and diagnostic commands. The helpers
use Compose project `sagepod` and prefer `.venv/bin/podman-compose`, with a fallback
to `podman-compose` on `PATH`. Setup always creates the repository's own `.venv`.

The local image is `localhost/sagepod-sagemath:10.7-pycryptosat`, or the corresponding
tag when `SAGE_TAG` is set. `Containerfile` installs `pycryptosat==5.11.21` in Sage's
Python environment and checks that the package lies outside `/home/sage`, where
bind mounts could hide it. It also tests a satisfiable and an unsatisfiable example
through Sage's CryptoMiniSat interface.
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

## Rebuild or repair

Rebuild the image after changing `Containerfile`:

```bash
bin/build-image.sh
./man-down.sh
./man-up.sh --no-follow
```

Building alone leaves the running container in place. Stop and start it to use the
new image. A failed build therefore does not remove a working container. For a
different Sage version, export `SAGE_TAG` before the sequence above. The optional
`bin/build-image.sh --sage-tag VERSION` selects only that build's version; export
the same value before starting it. Other base-image versions require validation.

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
[Podman rootless guide](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)
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

Check `podman ps` and `podman logs --tail 2000 sagepod`. Verify that the host port
is free and use the configured host port in the browser. `bin/verify.sh` checks
Sage and filesystem access; it is not an HTTP readiness check for Jupyter.

## Repository contents

| Path | Purpose |
| --- | --- |
| `Containerfile`, `podman-compose.yml` | Build and run the SagePod image. |
| `bin/setup.sh` | Prepare the installation and start it. |
| `bin/build-image.sh`, `bin/venvfix.sh` | Build the image and host Python environment. |
| `bin/fix-bind-mounts.sh`, `bin/show-mapped-ids.sh` | Manage and inspect rootless mount permissions. |
| `bin/verify.sh`, top-level helpers | Start, stop, and check the container. |
| `tests/` | Host-side regression tests, without a Sage image. |
| `compiling_sage/` | Separate host-source-build helpers; not part of the container setup. |
| [Setup provenance](docs/setup-provenance.md) | Sources and changes made when incorporating SageQueue's setup. |

Run the host-side checks with:

```bash
python3 -m unittest discover -s tests -v
```

These checks use command substitutes for Podman. With `setfacl` installed, they
also exercise inherited ACLs on temporary files. A complete installation check
requires `bin/setup.sh` on a supported rootless Podman host, followed by opening
Jupyter and evaluating a Sage notebook cell.

## License

MIT. The incorporated SageQueue code has the same author and license; see
[LICENSE](LICENSE).
