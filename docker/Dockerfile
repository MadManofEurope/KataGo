FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04
WORKDIR /opt/katago

ARG KATAGO_VER=v1.16.3
ARG KATAGO_FLAVOR=cuda12.8-cudnn9.8.0-linux-x64

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    ca-certificates \
    curl \
    unzip \
    libzip4t64 \
  && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  curl -fL -o katago.zip \
    "https://github.com/lightvector/KataGo/releases/download/${KATAGO_VER}/katago-${KATAGO_VER}-${KATAGO_FLAVOR}.zip"; \
  unzip -j katago.zip -d /opt/katago; rm -f katago.zip

RUN set -eux; cd /opt/katago; \
  F="$(find . -maxdepth 1 -type f -iregex '\./katago(\\.appimage)?' | head -n1 | sed 's|^./||')"; \
  if [ -z "$F" ]; then \
    F="$(find . -maxdepth 1 -type f -iname 'katago*' | head -n1 | sed 's|^./||')"; \
  fi; \
  if [ -z "$F" ]; then \
    echo "Unable to locate KataGo binary or AppImage in extracted archive" >&2; exit 1; \
  fi; \
  chmod +x "$F"; "./$F" --appimage-extract >/dev/null 2>&1 || true; \
  if [ -d squashfs-root ]; then \
    mv squashfs-root /opt/katago/app; \
    printf '#!/bin/sh\nexec /opt/katago/app/AppRun "$@"\n' > /opt/katago/katago; \
    rm -f "$F"; \
  else \
    mv "$F" /opt/katago/katago; \
  fi; chmod +x /opt/katago/katago

COPY docker/analysis.cfg /opt/katago/analysis.cfg
COPY docker/*.py /opt/katago/
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2388
CMD ["/entrypoint.sh"]
