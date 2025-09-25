#!/usr/bin/env bash
set -euo pipefail
IMG="${1:-katago-json:local}"
printf '%s\n' '{"id":"ping","action":"query_version"}' | \
  docker run --rm -i --gpus all \
    -v "$PWD/config:/config:ro" -v "$PWD/models:/models:ro" \
    --entrypoint /usr/local/bin/katago "$IMG" \
    analysis -config /config/analysis.cfg -model /models/latest.bin.gz | head -n1
