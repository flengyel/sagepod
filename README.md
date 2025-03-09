# SagePod: SageMath Containerization with Podman

This README describes how to containerize SageMath using Podman, with a focus on resolving permission issues between the host and container.

## Overview

SageMath is an open-source mathematics software system. Running it in a container provides:

- Isolation from host system dependencies
- Consistent environment across different machines
- Simplified deployment and version management

Containerizing SageMath presents specific challenges with file permissions when mounting host volumes for persistent storage of notebooks.

## Setup Requirements

- Ubuntu 24.04 or similar Linux distribution (works with WSL2)
- Podman installed
- Python 3.x (for podman-compose)
- SageMath container image from Docker Hub

## Python Virtual Environment Setup

This setup uses podman-compose in a Python virtual environment:

```bash
# Create a virtual environment named 'sagepod'
python -m venv sagepod

# Activate the virtual environment
source sagepod/bin/activate

# Install required packages from requirements.txt
pip install -r requirements.txt
```

Remember to activate the virtual environment before running podman-compose commands.

## The Permission Challenge

When running SageMath in a container, a specific permission challenge occurs:

1. Inside the container, SageMath runs as the `sage` user (UID/GID 1000:1000)
2. On the host, your user account may have the same UID/GID (1000:1000)
3. Podman maps container UIDs to high-numbered UIDs on the host (e.g., 100999:100999) for security
4. This mapping can cause permission issues with mounted volumes and Jupyter notebooks

## Solution: podman-compose.yml

Create a `podman-compose.yml` file with the following configuration:

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
- Uses volume options `Z,U` for SELinux context and UID/GID mapping

### Important Note on User ID

The `user: "1000:1000"` line should match the UID:GID of the sage user in the container. Additionally, you should verify that this matches your host system user:

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
```

This creates a user outside the normal UID range that matches Podman's namespace mapping.

## Important Notes

1. Avoid creating a `/home/$USER/.config/containers/containers.conf` file with `userns = "keep-id"` as this conflicts with the compose file settings.

2. The high UID (100999) is outside the normal range to prevent conflicts with system-assigned UIDs.

3. When creating the user, you'll see a message: `useradd warning: sage's uid 100999 outside of the UID_MIN 1000 and UID_MAX 60000 range.` This is expected.

## Running the Container

### Helper Scripts

The repository includes these helper scripts:

**man-up.sh** - Start the container and follow logs:
```bash
#!/bin/bash
podman-compose -f ~/sagepod/podman-compose.yml up -d && podman logs -f sagemath
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

### Starting the Container

```bash
# Activate the virtual environment if not already activated
source ~/sagepod/bin/activate

# Start the container and follow logs
./man-up.sh

# In a different terminal, you can enter the container with
./run-bash.sh

# To stop the container
./man-down.sh
```

Access Jupyter at `http://localhost:8888` in your browser.

## File Ownership

With this setup:
- Inside container: Files appear as sage:sage (1000:1000)
- On host: Files appear as sage:sage (100999:100999)

This configuration allows Jupyter to read and write notebooks without permission errors.

### Verifying File Ownership

After setting up and running the container for the first time, verify the file ownership on the host:

```bash
ls -la ~/Jupyter/
```

You should see files owned by sage:sage. If you see numeric UIDs instead (like 100999:100999), it confirms that Podman is mapping the UIDs correctly, but the sage user has not been properly created on the host. In this case, revisit the "Host System Configuration" section.

If you see different UIDs, you may need to adjust the UID:GID values in your setup to match what Podman is using in your specific environment.

## Troubleshooting

If you encounter read-only notebooks or permission errors:

1. Verify you've added your user to the sage group
2. Check that no conflicting containers.conf file exists
3. Ensure the Jupyter directory exists on your host before starting the container
4. You may need to log out and back in for group changes to take effect

If you encounter issues with podman-compose:

1. Ensure the virtual environment is activated with `source ~/sagepod/bin/activate`
2. Verify all dependencies are installed with `pip list | grep podman-compose`
3. Try updating dependencies with `pip install --upgrade podman-compose podman`
4. Check the helper scripts have proper paths for your environment

## License

This documentation is provided under the MIT License.

