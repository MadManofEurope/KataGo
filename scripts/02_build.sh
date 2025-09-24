#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

GIT_SHA_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
export GIT_SHA_SHORT

docker compose build --no-cache
