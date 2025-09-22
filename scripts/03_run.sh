#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Ensure NVIDIA runtime is available and driver installed.
docker compose up -d
docker logs -f katago-analysis
