# CUDA-enabled KataGo runtime built on a cuDNN 8 base image
FROM nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu22.04

ARG KATAGO_VER=v1.16.3
ARG KATAGO_FLAVOR=cuda12.2-cudnn8-linux-x64
WORKDIR /opt/katago

# Install minimal runtime dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    unzip \
    socat \
    python3-minimal \
 && rm -rf /var/lib/apt/lists/*

# Fetch KataGo release (use ZIP to avoid AppImage/FUSE issues)
RUN curl -fsSL -o katago.zip \
    "https://github.com/lightvector/KataGo/releases/download/${KATAGO_VER}/katago-${KATAGO_VER}-${KATAGO_FLAVOR}.zip" \
 && unzip -j katago.zip -d /opt/katago \
 && rm katago.zip \
 && chmod +x /opt/katago/katago

# Provide a default analysis configuration inside the image
COPY config/analysis.cfg /opt/katago/analysis.cfg
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/models", "/config"]

EXPOSE 2388
ENTRYPOINT ["/entrypoint.sh"]
