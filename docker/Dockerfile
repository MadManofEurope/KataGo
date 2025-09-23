# CUDA-enabled KataGo runtime built on a CUDA 12.5 / Ubuntu 24.04 base image
FROM nvidia/cuda:12.5.1-runtime-ubuntu24.04

ARG KATAGO_VER=v1.16.3
ARG KATAGO_FLAVOR=cuda12.5-linux-x64
WORKDIR /opt/katago

# Install minimal runtime dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    unzip \
 && rm -rf /var/lib/apt/lists/*

# Fetch KataGo release (use ZIP to avoid AppImage/FUSE issues)
RUN set -eux; \
    curl -fL -o katago.zip \
        "https://github.com/lightvector/KataGo/releases/download/${KATAGO_VER}/katago-${KATAGO_VER}-${KATAGO_FLAVOR}.zip"; \
    unzip -j katago.zip -d /opt/katago; \
    rm katago.zip; \
    chmod +x /opt/katago/katago

VOLUME ["/models", "/config"]

EXPOSE 2388
ENTRYPOINT ["/opt/katago/katago", "analysis", "-config", "/config/analysis.cfg", "-model", "/models/latest.bin.gz", "-override-config", "allowResignation=false"]
