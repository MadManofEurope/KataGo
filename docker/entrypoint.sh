#!/usr/bin/env bash
set -euo pipefail

MODEL="${KATAGO_MODEL:-/models/latest.bin.gz}"
CFG="/opt/katago/analysis.cfg"
PORT="${KATAGO_PORT:-2388}"

if [ ! -f "$MODEL" ]; then
  echo "Model not found at $MODEL"; ls -l /models || true; exit 1
fi

echo "Starting KataGo analysis @ 0.0.0.0:${PORT} with model $MODEL"
exec /opt/katago/katago analysis \
  -model "$MODEL" \
  -config "$CFG" \
  -analysis-threads 2 \
  -analysis-addr "0.0.0.0:${PORT}"
