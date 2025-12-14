#!/bin/bash
podman-compose -f podman-compose.yml up -d && podman logs -f sagemath
echo
echo "Open in Windows: http://localhost:8888"
echo "If token auth is on, grab the token from: podman logs sagemath | grep -o 'token=[0-9a-f]*' | head -1"
