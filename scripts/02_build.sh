#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo local)"

docker compose build --no-cache
