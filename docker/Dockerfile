# CUDA-enabled KataGo runtime built on a CUDA 12.5 / Ubuntu 24.04 base image
FROM nvidia/cuda:12.5.1-cudnn-runtime-ubuntu24.04

ARG KATAGO_VER=v1.16.3
ARG KATAGO_FLAVOR=cuda12.5-cudnn8.9.7-linux-x64
WORKDIR /opt/katago

# Install minimal runtime dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    unzip \
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
COPY docker/serve.py /opt/katago/serve.py
RUN chmod +x /entrypoint.sh
RUN chmod +x /opt/katago/serve.py

VOLUME ["/models", "/config"]

EXPOSE 2388
ENTRYPOINT ["/entrypoint.sh"]
