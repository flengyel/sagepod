FROM ghcr.io/sagemath/sage/sage-debian-bullseye-standard-with-targets-optional:10.7

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    make gcc g++ cmake pkg-config python3-dev git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

USER sage
RUN sage -i pycryptosat

