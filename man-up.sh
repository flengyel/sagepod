#!/bin/bash
podman-compose -f ~/sagepod/podman-compose.yml up -d && podman logs -f sagemath
