# SagePod: SageMath Containerization with Podman (WSL2)

This repository runs the SageMath container under **Ubuntu on WSL2** using **rootless Podman** and `podman-compose`.
It bind-mounts host directories for notebooks and Jupyter configuration and exposes Jupyter on port **8888**.

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

### 2) Start / stop

```bash
chmod +x man-up.sh man-down.sh run-bash.sh

./man-up.sh --open
# Windows browser: http://localhost:8888

./man-down.sh
```

## Compose configuration

See `podman-compose.yml`. The default configuration:

- runs the container as `1000:1000` (the `sage` user in the container),
- exposes `8888:8888`,
- bind-mounts:
  - `${HOME}/Jupyter` → `/home/sage/notebooks`
  - `${HOME}/.jupyter` → `/home/sage/.jupyter`

**Tip:** avoid running `podman-compose` with `sudo`. If you do, `~` expands to `/root`, and you will accidentally mount
`/root/Jupyter` instead of your real notebook directory.

## Bind mounts, user namespaces, and “mystery” UIDs

Rootless Podman uses a user namespace. Even though Sage runs as `1000:1000` inside the container, those IDs may show up
as *different* high-numbered IDs on the host. That mapping depends on your `/etc/subuid` and `/etc/subgid`, so **it is
not a fixed value like 100999**.

### Discover the host-mapped UID/GID for container 1000:1000

**Method A (fast; no running container required):**

```bash
HUID=$(podman unshare awk -v id=1000 '$1<=id && id<($1+$3){print $2+(id-$1);exit}' /proc/self/uid_map)
HGID=$(podman unshare awk -v id=1000 '$1<=id && id<($1+$3){print $2+(id-$1);exit}' /proc/self/gid_map)
echo "container 1000:1000 -> host ${HUID}:${HGID}"
```

**Method B (probe file; confirms the mapping end-to-end):**

```bash
./man-up.sh --no-follow
podman exec -u 1000:1000 sagemath sh -lc 'echo probe > /home/sage/notebooks/.uidgid_probe'
stat -c 'host_uid=%u host_gid=%g  %n' "${HOME}/Jupyter/.uidgid_probe"
```

### Make the mounted directories writable from the host

If you see numeric owners on `${HOME}/Jupyter` (like `101000:101000`), you have two practical options:

**Option 1 (recommended): ACLs (no special users/groups needed)**

```bash
sudo apt-get install -y acl
sudo setfacl -R -m "u:${USER}:rwX" -m "d:u:${USER}:rwX" "${HOME}/Jupyter" "${HOME}/.jupyter"
```

**Option 2: create a cosmetic group/user matching the mapped IDs**

Use Method A or B to get `HUID`/`HGID`, then:

```bash
# Example: replace HUID/HGID with what you discovered.
sudo groupadd -g "${HGID}" sagepod || true
sudo useradd  -u "${HUID}" -g "${HGID}" -s /usr/sbin/nologin -M sagepod-sage || true
sudo usermod -a -G sagepod "${USER}"
newgrp sagepod
```

## Troubleshooting

### `RunRoot ... is not writable` / `/run/user/<uid>: permission denied`

This is almost always a WSL2 systemd issue. Re-check the **systemd prerequisite** above.

### Jupyter URL / token

The helper script prints a Windows-friendly URL:

- `http://localhost:8888`

If you need the token:

```bash
podman logs sagemath | grep -Eo 'token=[0-9a-f]+' | tail -n 1
```

## Raspberry Pi note (arm64)

As of 28 June 2025, the Docker Hub `sagemath/sagemath:latest` image did not provide an arm64 variant.
On a Raspberry Pi 5 you may see:

```text
no image found in image index for architecture arm64, variant "v8"
```

## License

MIT
