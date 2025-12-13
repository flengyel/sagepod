#!/bin/bash
podman-compose -f podman-compose.yml up -d && podman logs -f sagemath
