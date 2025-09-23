#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export IMAGE_TAG="$(git rev-parse --short HEAD)"
docker compose build --no-cache
