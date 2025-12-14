# SagePod: SageMath Containerization with Podman

This README describes utilities to download and run SageMath containers under Ubuntu Linux under WSL2 using `podman-compose`.
A `podman-compose` script handles downloading SageMath containers and mounts container directories on the host system 
for Jupyter notebook access and configuration. Shell scripts automate starting and stopping the container, and provide interactive container access.

## Overview

SageMath is an open-source mathematics software system. Running it in a container provides:

- Isolation from host system dependencies
- Consistent environment across different machines
- Simplified deployment and version management

Containerizing SageMath presents specific challenges with file permissions when mounting host volumes for persistent storage of notebooks.

## Setup Requirements

- Ubuntu 24.04 or similar Linux distribution (works with WSL2)
- Python 3.x (for podman-compose)
- SageMath container image from Docker Hub

NOTE: As of 28 June 2025, no arm64 architecture SageMath container images are available on Docker Hub. On the Raspberry Pi 5, an attempt to download and run a SageMath Docker container on a Rasperry Pi 5 results in the following catastrophic, extinction level error.

```bash
(sagepod) flengyel@pironman5:~/Python/sagepod $ ./man-up.sh
Trying to pull docker.io/sagemath/sagemath:latest...
Error: choosing an image from manifest list docker://sagemath/sagemath:latest: no image found in image index for architecture arm64, variant "v8", OS linux
```

## Python Virtual Environment Setup

This setup uses podman-compose in a Python virtual environment. The repository includes a `venvfix.sh` script 
to simplify the setup process:

```bash
# Make the script executable
chmod +x venvfix.sh

# Run the script to set up the virtual environment
./venvfix.sh

# Activate the virtual environment
source bin/activate
```

The script will:
1. Remove any existing virtual environment components
2. Create a new virtual environment
3. Upgrade pip, setuptools, and wheel
4. Install all dependencies from requirements.txt

Remember to activate the virtual environment before running podman-compose commands.

## Bind Mounts and User Namespaces

This containerized SageMath setup uses bind mounts to share directories between the host and container. Bind mounts directly map host directories to container directories, enabling persistent storage of notebooks and configurations.

Podman implements user namespaces as a security feature, which isolates users in the container from users on the host system. With user namespaces:

1. Inside the container, SageMath runs as the `sage` user (UID/GID 1000:1000)
2. On the host, Podman maps this container user to a high-numbered UID (typically 100999:100999)

The bind mount options (`:Z,U`) in the configuration ensure proper file access across this namespace boundary. 
The `Z` option handles SELinux contexts, while the `U` option maintains the correct user mapping between container and host.

## Podman Compose Configuration

The repository includes a `podman-compose.yml` file with the following configuration:

```yaml
version: '3.8'
services:
  sagemath:
    image: docker.io/sagemath/sagemath:latest
    container_name: sagemath
    user: "1000:1000"
    ports:
      - "8888:8888"
    command: sage-jupyter
    volumes:
      - ~/Jupyter:/home/sage/notebooks:Z,U
      - ~/.jupyter:/home/sage/.jupyter:Z,U
networks:
  default:
    driver: bridge
```

Key elements:
- Sets container user to 1000:1000 (matches sage user in container)
- Maps port 8888 for Jupyter access
- Uses bind mounts with `:Z,U` options where:
  - `Z` enables SELinux relabeling for container access
  - `U` applies the container's UID/GID mapping to the bind mount
- The two bind mounts expect host directories at `~/Jupyter` and `~/.jupyter`. The helper scripts will create them if they don't already exist so Jupyter starts cleanly.

### Note on User ID

The `user: "1000:1000"` line should match the UID:GID of the sage user in the container. You should verify that this matches your host system user:

```bash
id $USER
```

If your host user's UID:GID does not match 1000:1000, you have two options:

1. Update the podman-compose.yml to match your host user's UID:GID
2. Keep 1000:1000 and create a matching sage user on the host (recommended if the container's sage user is fixed at 1000:1000)

For most standard Linux installations, the first user account is assigned 1000:1000, but this may vary.

## Host System Configuration

To align file ownership on the host, create a matching `sage` user and group:

```bash
# Create the sage group with GID 100999
sudo groupadd -g 100999 sage

# Create the sage user with UID 100999 and primary group sage
sudo useradd -u 100999 -g 100999 -s /bin/bash -m sage

# Add your user to the sage group for file access
sudo usermod -a -G sage $USER

# Create the Jupyter directory if it doesn't exist
mkdir -p ~/Jupyter

# Set appropriate permissions on the Jupyter directory
sudo chown sage:sage ~/Jupyter
sudo chmod 775 ~/Jupyter
```

This creates a user outside the normal UID range that matches Podman's namespace mapping.

## Important Notes

1. Avoid creating a `/home/$USER/.config/containers/containers.conf` file with `userns = "keep-id"` as this 
conflicts with the compose file settings.

2. The high UID (100999) is outside the normal range to prevent conflicts with system-assigned UIDs.

3. When creating the user, you'll see a message: `useradd warning: sage's uid 100999 outside of the UID_MIN 1000 and UID_MAX 60000 range.` This is expected.

## Running the Container

### Helper Scripts

The repository includes these helper scripts:

Each script reads the `podman-compose.yml` that sits beside it in this repository, so the configured volumes and user mappings are always used regardless of where you cloned the project.

**man-up.sh** - Start the container and follow logs:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMPOSE_FILE="${SCRIPT_DIR}/podman-compose.yml"

mkdir -p "$HOME/Jupyter" "$HOME/.jupyter"

podman-compose -f "${COMPOSE_FILE}" up -d

echo
echo "Open in Windows: http://localhost:8888"
echo "If token auth is on, grab it with:"
echo "  podman logs sagemath | grep -o 'token=[0-9a-f]*' | head -1"

exec podman logs -f sagemath
```


**man-down.sh** - Stop the container:

```bash
#!/bin/bash
podman-compose -f ~/sagepod/podman-compose.yml down
```

**run-bash.sh** - Start a bash shell in the running container:

```bash
#!/bin/bash
podman exec -it sagemath /bin/bash
```

Make sure to make the scripts executable:

```bash
chmod +x man-up.sh man-down.sh run-bash.sh
```

Access Jupyter at `http://localhost:8888` in your browser.

## File Ownership

With this bind mount configuration:

- Inside container: Files appear as sage:sage (1000:1000)
- On host: Files appear as sage:sage (100999:100999)

This user namespace mapping allows Jupyter to read and write notebooks without permission errors.

### Verifying File Ownership

After setting up and running the container for the first time, verify the file ownership on the host:

```bash
ls -la ~/Jupyter/
```

You should see files owned by `sage:sage`. If you see numeric UIDs instead (like 100999:100999), it confirms 
that Podman is mapping the UIDs correctly, but the sage user has not been properly created on the host. 
In this case, revisit the "Host System Configuration" section.

If you see different UIDs, you may need to adjust the UID:GID values in your setup to match what Podman uses in your environment.

## Troubleshooting

If you encounter read-only notebooks or permission errors:

1. Verify you've added your user to the sage group
2. Check that no conflicting containers.conf file exists
3. Ensure the Jupyter directory exists on your host before starting the container
4. You may need to log out and back in for group changes to take effect

If you encounter issues with podman-compose:

1. Ensure the virtual environment is activated with `source ~/sagepod/bin/activate`
2. Verify all dependencies are installed with `pip list | grep podman-compose`
3. Try updating dependencies with `pip install --upgrade podman-compose`
4. Check the helper scripts have proper paths for your environment

## Documentation

- [SageMath Documentation](https://doc.sagemath.org/)
- [Jupyter Notebook Documentation](https://jupyter-notebook.readthedocs.io/)
- [Podman Documentation](https://docs.podman.io/)
- [Podman-Compose GitHub Repository](https://github.com/containers/podman-compose)

## License

This documentation is provided under the MIT License.
