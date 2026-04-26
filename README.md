# SagePod

`sagepod` runs a SageMath/Jupyter container under rootless Podman on WSL2.

Current restore model:

- WSL2 distro: Debian or Ubuntu
- container runtime: rootless Podman
- compose runner: `podman-compose`
- networking: `slirp4netns`
- notebook directory on host: `${HOME}/Jupyter`
- Jupyter URL from Windows: `http://localhost:8889`
- container name: `sagepod`
- Sage image: `localhost/sagequeue-sagemath:10.7-pycryptosat`

`sagepod` deliberately reuses the local Sage image built by `sagequeue`, rather than building a second Sage image.

## Prerequisites

### WSL2 with systemd

Edit `/etc/wsl.conf`:

```ini
[boot]
systemd=true
```

Then from Windows PowerShell:

```powershell
wsl.exe --shutdown
```

Reopen the WSL distro and check:

```bash
ps -p 1 -o comm=
systemctl --user show-environment >/dev/null && echo "systemd --user OK"
podman ps
```

Expected:

```text
systemd
systemd --user OK
```

`podman ps` should run as the normal Linux user, not via `sudo`.

### Required Debian/Ubuntu packages

Install the small host-side tools:

```bash
sudo apt update
sudo apt install -y podman slirp4netns acl python3-venv
```

If `podman-compose` is not installed globally, the helper scripts can use the repo-local copy from:

```text
${HOME}/src/sagequeue/.venv/bin/podman-compose
```

A local `sagepod` venv may also be used if present.

### Rootless Podman defaults for WSL2

For this Debian/Ubuntu WSL2 restore, rootless Podman works best with `cgroupfs`, file logging, and `slirp4netns`.

Create or update:

```bash
mkdir -p ~/.config/containers

cat > ~/.config/containers/containers.conf <<'CONF'
[engine]
cgroup_manager="cgroupfs"
events_logger="file"

[network]
default_rootless_network_cmd="slirp4netns"
CONF
```

Check:

```bash
podman info --format 'cgroupManager={{.Host.CgroupManager}} eventsLogger={{.Host.EventLogger}}'
```

Expected:

```text
cgroupManager=cgroupfs eventsLogger=file
```

## Shared Sage image

`sagepod` uses:

```text
localhost/sagequeue-sagemath:10.7-pycryptosat
```

This image is built by the `sagequeue` repository. The usual route is:

```bash
cd ~/src/sagequeue
bin/setup.sh
```

or explicitly:

```bash
cd ~/src/sagequeue
bin/build-image.sh
```

Verify that the image exists:

```bash
podman image exists localhost/sagequeue-sagemath:10.7-pycryptosat && echo "Sage image present"
```

Verify `pycryptosat` inside the image:

```bash
podman run --rm --network slirp4netns localhost/sagequeue-sagemath:10.7-pycryptosat \
  bash -lc 'cd /sage && ./sage -python -c "import pycryptosat; print(pycryptosat.__file__)"'
```

Expected path begins with:

```text
/sage/local/
```

## Bind-mount directories

`podman-compose.yml` bind-mounts these host directories:

```text
${HOME}/Jupyter              -> /home/sage/notebooks
${HOME}/.jupyter             -> /home/sage/.jupyter
${HOME}/.sagepod-dot_sage    -> /home/sage/.sage
${HOME}/.sagepod-local       -> /home/sage/.local
${HOME}/.sagepod-config      -> /home/sage/.config
${HOME}/.sagepod-cache       -> /home/sage/.cache
```

Create them:

```bash
mkdir -p \
  ~/Jupyter \
  ~/.jupyter \
  ~/.sagepod-dot_sage \
  ~/.sagepod-local \
  ~/.sagepod-config \
  ~/.sagepod-cache
```

Fix host-side permissions for rootless Podman bind mounts:

```bash
chmod +x fix_bind_mounts.sh
./fix_bind_mounts.sh

sudo chgrp sage ~/.sagepod-dot_sage ~/.sagepod-local ~/.sagepod-config ~/.sagepod-cache
chmod 770 ~/.sagepod-dot_sage ~/.sagepod-local ~/.sagepod-config ~/.sagepod-cache
```

The second pair of commands is needed because the historical `fix_bind_mounts.sh` fixes `~/Jupyter` and `~/.jupyter`, but may not cover all `.sagepod-*` directories.

## Start and stop

Make scripts executable:

```bash
chmod +x man-up.sh man-down.sh run-bash.sh show-mapped-ids.sh check_cryptominisat_version.sh
```

Start Jupyter without following logs:

```bash
./man-up.sh --no-follow
```

Open from Windows:

```text
http://localhost:8889
```

Get the token if needed:

```bash
podman logs sagepod 2>&1 | grep -Eo 'token=[0-9a-f]+' | tail -n 1
```

Stop the container:

```bash
./man-down.sh
```

Follow logs:

```bash
podman logs -f sagepod
```

Interactive shell inside the container:

```bash
podman exec -it sagepod bash
```

## Validation

Check the running containers:

```bash
podman ps --format '{{.Names}}  {{.Ports}}  {{.Image}}'
```

Expected `sagepod` line:

```text
sagepod  0.0.0.0:8889->8888/tcp  localhost/sagequeue-sagemath:10.7-pycryptosat
```

Check Sage and `pycryptosat`:

```bash
podman exec sagepod bash -lc \
  'cd /sage && ./sage -python -c "from sage.all import factor; import pycryptosat; print(factor(2**10-1)); print(pycryptosat.__file__)"'
```

Expected output includes:

```text
3 * 11 * 31
/sage/local/
```

## Compose notes

The active compose file uses:

```yaml
image: localhost/sagequeue-sagemath:${SAGE_TAG:-10.7}-pycryptosat
container_name: sagepod
network_mode: ${SAGEPOD_NETWORK_MODE:-slirp4netns}
ports:
  - "${PORT:-8889}:8888"
```

Override port:

```bash
PORT=8890 ./man-up.sh --no-follow
```

Override network mode:

```bash
SAGEPOD_NETWORK_MODE=slirp4netns ./man-up.sh --no-follow
```

## Troubleshooting

### `podman-compose` not found

Use the `sagequeue` venv path, or build a local `sagequeue` venv:

```bash
cd ~/src/sagequeue
bin/setup.sh
```

Then retry:

```bash
cd ~/src/sagepod
./man-up.sh --no-follow
```

### `netavark: nftables error`

Use `slirp4netns`. The compose file defaults to:

```yaml
network_mode: ${SAGEPOD_NETWORK_MODE:-slirp4netns}
```

Also make sure `~/.config/containers/containers.conf` contains:

```ini
[network]
default_rootless_network_cmd="slirp4netns"
```

### TLS error pulling from GHCR

If building the shared image fails with a certificate issuer such as:

```text
Gateway CA - Cloudflare Managed
```

then Cloudflare Gateway TLS inspection is intercepting `ghcr.io`.

Add a Cloudflare Zero Trust HTTP “Do Not Inspect” rule for:

```text
ghcr.io
```

Then verify in WSL:

```bash
printf '' | openssl s_client -connect ghcr.io:443 -servername ghcr.io -showcerts 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -fingerprint -sha256
```

The issuer should no longer be the Cloudflare Gateway CA.

### Permission errors under `/home/sage/.local`, `/home/sage/.config`, or `/home/sage/.cache`

Recreate and fix the `.sagepod-*` bind-mount directories:

```bash
mkdir -p ~/.sagepod-dot_sage ~/.sagepod-local ~/.sagepod-config ~/.sagepod-cache
sudo chgrp sage ~/.sagepod-dot_sage ~/.sagepod-local ~/.sagepod-config ~/.sagepod-cache
chmod 770 ~/.sagepod-dot_sage ~/.sagepod-local ~/.sagepod-config ~/.sagepod-cache
```

### Wrong container name

Current container name is:

```text
sagepod
```

Old scripts or commands may still refer to:

```text
sagemath
```

Check live names:

```bash
podman ps --format '{{.Names}}'
```

## License

MIT
