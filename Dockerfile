FROM nvidia/cuda:12.5.1-runtime-ubuntu24.04 AS downloader

ARG KATAGO_VER=v1.16.3
ARG KATAGO_FLAVOR=cuda12.5-cudnn8.9.7-linux-x64

WORKDIR /tmp/katago

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
  && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  curl -fL -o katago.zip \
    "https://github.com/lightvector/KataGo/releases/download/${KATAGO_VER}/katago-${KATAGO_VER}-${KATAGO_FLAVOR}.zip"; \
  unzip -j katago.zip katago; \
  rm katago.zip

FROM nvidia/cuda:12.5.1-runtime-ubuntu24.04

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libzip4t64 \
    python3 \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /usr/sbin/nologin katago

WORKDIR /opt/katago

COPY --from=downloader /tmp/katago/katago /opt/katago/katago
COPY serve.py /opt/katago/serve.py
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 755 /opt/katago/katago /opt/katago/serve.py /usr/local/bin/entrypoint.sh \
  && chown -R katago:katago /opt/katago /usr/local/bin/entrypoint.sh

USER katago

EXPOSE 2388
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
