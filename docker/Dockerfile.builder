# Builder image: fetch KataGo release assets and prepare binaries.
FROM ubuntu:24.04

ARG KATAGO_VER=v1.16.3
ARG KATAGO_FLAVOR=cuda12.5-cudnn8.9.7-linux-x64

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /build

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
  && rm -rf /var/lib/apt/lists/*

RUN curl -L -o katago.zip \
      "https://github.com/lightvector/KataGo/releases/download/${KATAGO_VER}/katago-${KATAGO_VER}-${KATAGO_FLAVOR}.zip" \
  && unzip katago.zip -d katago \
  && rm katago.zip \
  && chmod +x katago/katago
