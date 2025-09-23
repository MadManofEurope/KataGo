#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || true)"
if [[ -z "${GIT_SHA}" ]]; then
  GIT_SHA="local"
fi
export GIT_SHA

docker compose build --no-cache
