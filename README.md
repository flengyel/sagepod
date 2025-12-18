# SagePod: SageMath Containerization with Podman (WSL2)

This repository runs a SageMath container under **Ubuntu on WSL2** using **rootless Podman** and `podman-compose`.
It bind-mounts host directories for notebooks and Sage/Jupyter state, and exposes Jupyter on port **8888**.

## Quick start

### 0) WSL2 prerequisite: enable systemd

Rootless Podman needs a working per-user runtime directory (`/run/user/<uid>`). On WSL2, you typically only get that
reliably with systemd enabled.

Edit `/etc/wsl.conf` (merge with any existing sections you already have; do not delete them):

```ini
[boot]
systemd=true
```

Then from **Windows PowerShell**:

```powershell
wsl.exe --shutdown
```

Open Ubuntu again and sanity-check:

```bash
ps -p 1 -o comm=
podman ps
```

If `podman ps` works as your normal user, you are good.

### 1) Create the Python virtual environment

```bash
chmod +x venvfix.sh
./venvfix.sh
```

You do **not** need to `source bin/activate` just to use the helper scripts; they prefer the repo-local venv
`bin/podman-compose` automatically.

### 2) Create the bind-mount directories (one-time)

The compose file bind-mounts the following host directories:

- `${HOME}/Jupyter` → `/home/sage/notebooks`
- `${HOME}/.jupyter` → `/home/sage/.jupyter`

And (for Sage/Jupyter runtime state):

- `${HOME}/.sagepod-dot_sage` → `/home/sage/.sage`  (sets `DOT_SAGE`)
- `${HOME}/.sagepod-local` → `/home/sage/.local`
- `${HOME}/.sagepod-config` → `/home/sage/.config`
- `${HOME}/.sagepod-cache` → `/home/sage/.cache`

Create them:

```bash
mkdir -p "${HOME}/Jupyter" "${HOME}/.jupyter"          "${HOME}/.sagepod-dot_sage" "${HOME}/.sagepod-local"          "${HOME}/.sagepod-config" "${HOME}/.sagepod-cache"

chmod 700 "${HOME}/.sagepod-dot_sage" "${HOME}/.sagepod-local"           "${HOME}/.sagepod-config" "${HOME}/.sagepod-cache"
```

#### Make `${HOME}/Jupyter` and `${HOME}/.jupyter` host-writable (recommended)

Rootless Podman uses a user namespace, so container UID/GID `1000:1000` may appear as different numeric IDs on the host.
If you want to avoid “mystery UID” pain on the host (especially for notebooks), run:

```bash
chmod +x fix_bind_mounts.sh
./fix_bind_mounts.sh
```

This script computes the host-mapped UID/GID for container `1000:1000`, fixes ownership, and installs ACLs so your host
user keeps `rwX` access. (It uses `sudo` internally and requires `setfacl`.)  

### 3) Start / stop

```bash
chmod +x man-up.sh man-down.sh run-bash.sh

./man-up.sh --open
# Windows browser: http://localhost:8888

./man-down.sh
```

To get an interactive shell inside the running container:

```bash
./run-bash.sh
```

## Compose configuration

See `podman-compose.yml`. The configuration in this repository is intended for the **GHCR “with-targets-optional”** image:

- image: `ghcr.io/sagemath/sage/sage-debian-bullseye-standard-with-targets-optional:${SAGE_TAG:-10.7}`
- working directory: `/sage`
- Jupyter starts via `./sage -n jupyter ...`

**Tip:** avoid running `podman-compose` with `sudo`. If you do, `~` expands to `/root`, and you will accidentally mount
`/root/Jupyter` instead of your real notebook directory.

## Optional components: XOR-capable SAT backend (CryptoMiniSat via pycryptosat)

If you want Sage’s `cryptominisat` SAT backend to support native XOR constraints, you need the `pycryptosat` bindings
installed inside Sage’s Python environment.

The steps below are the exact ones that worked in this setup.

### 1) Install a build toolchain inside the container (one-time)

```bash
podman exec -u 0 -it sagemath bash -lc   'apt-get update && apt-get install -y --no-install-recommends      build-essential cmake pkg-config    && rm -rf /var/lib/apt/lists/*'
```

### 2) Install `pycryptosat` from source inside Sage (pinned)

Run this as the normal container user (no `-u 0`):

```bash
podman exec -it sagemath bash -lc   'cd /sage && ./sage -pip uninstall -y pycryptosat || true'
```

Then force a source build (no binary wheel) and pin the working version:

```bash
podman exec -it sagemath bash -lc   'cd /sage && ./sage -pip install --no-binary=pycryptosat pycryptosat==5.11.21'
```

### 3) Verify the bindings work

```bash
podman exec -it sagemath bash -lc   'cd /sage && ./sage -python -c "from pycryptosat import Solver; s=Solver(); s.add_clause([1]); print(s.solve())"'
```

You should see a satisfiable result (e.g. `(True, ...)`).

Optional: verify Sage can instantiate the solver wrapper:

```bash
podman exec -it sagemath bash -lc   'cd /sage && ./sage -python - <<'"'"'PY'"'"'
from sage.sat.solvers.satsolver import SAT
S = SAT(solver="cryptominisat")
S.add_clause((1,))
print(S())
PY'
```

### 4) (Optional) add a `sage` wrapper on PATH inside the container

In this image, the Sage launcher lives at `/sage/sage` and is not necessarily on `$PATH`.
If you want `sage` available everywhere inside the container:

```bash
podman exec -u 0 -it sagemath bash -lc 'ln -sf /sage/sage /usr/local/bin/sage'
podman exec -it sagemath bash -lc 'which sage && sage --version'
```

## Troubleshooting

### Permission errors under `/home/sage/.local` or `/home/sage/.sage`

These are almost always caused by missing bind mounts for the Sage/Jupyter state directories.
Re-check that you created the host directories in “Create the bind-mount directories” above, and that `podman-compose.yml`
includes the corresponding volume mounts.

### `RunRoot ... is not writable` / `/run/user/<uid>: permission denied`

This is almost always a WSL2 systemd issue. Re-check the **systemd prerequisite** above.

### Jupyter URL / token

The helper script prints a Windows-friendly URL:

- `http://localhost:8888`

If you need the token:

```bash
podman logs sagemath | grep -Eo 'token=[0-9a-f]+' | tail -n 1
```

## License

MIT
