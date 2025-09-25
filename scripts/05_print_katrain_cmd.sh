#!/usr/bin/env bash
set -euo pipefail
TAG="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
echo "/usr/bin/docker run --rm -i --gpus all -v \"$HOME/KataGo/config:/config:ro\" -v \"$HOME/KataGo/models:/models:ro\" --entrypoint /usr/local/bin/katago katago-json:${TAG} analysis -config /config/analysis.cfg -model /models/latest.bin.gz"
