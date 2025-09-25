FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04 AS downloader

WORKDIR /tmp/katago

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
  && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  curl -fL -o katago.zip \
    "https://github.com/lightvector/KataGo/releases/download/v1.16.3/katago-v1.16.3-cuda12.1-cudnn8.9.7-linux-x64.zip"; \
  unzip -j katago.zip katago; \
  rm katago.zip

FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libzip4 \
    python3 \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /usr/sbin/nologin katago

WORKDIR /opt/katago

COPY --from=downloader /tmp/katago/katago /opt/katago/katago.AppImage

# Extract the AppImage so the runtime can execute without FUSE
RUN set -eux; \
  chmod +x /opt/katago/katago.AppImage; \
  /opt/katago/katago.AppImage --appimage-extract; \
  mv squashfs-root /opt/katago/appdir; \
  chmod +x /opt/katago/appdir/AppRun; \
  ln -sf /opt/katago/appdir/AppRun /opt/katago/katago; \
  ln -sf /opt/katago/appdir/AppRun /usr/local/bin/katago; \
  rm /opt/katago/katago.AppImage
COPY serve.py /opt/katago/serve.py
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 755 /opt/katago/appdir/AppRun /opt/katago/serve.py /usr/local/bin/entrypoint.sh \
  && chown -R katago:katago /opt/katago /usr/local/bin/entrypoint.sh

USER katago

EXPOSE 2388
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
