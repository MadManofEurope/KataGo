# CUDA-enabled KataGo runtime
FROM nvidia/cuda:12.3.2-runtime-ubuntu24.04

ARG KATAGO_VER=v1.16.2
WORKDIR /opt/katago

# Minimal deps
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl unzip python3-minimal netcat-openbsd \
 && rm -rf /var/lib/apt/lists/*

# Fetch KataGo release (Linux CUDA build)
# Verify checksums in production if desired.
RUN curl -L -o katago.zip \
    "https://github.com/lightvector/KataGo/releases/download/${KATAGO_VER}/KataGo-${KATAGO_VER}-Linux-x64-cuda.zip" \
 && unzip katago.zip -d /opt/katago \
 && rm katago.zip \
 && chmod +x /opt/katago/katago

# Config + entrypoint
COPY analysis.cfg /opt/katago/analysis.cfg
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Models mounted at /models
VOLUME ["/models"]

EXPOSE 2388
ENTRYPOINT ["/entrypoint.sh"]
