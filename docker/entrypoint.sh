#!/usr/bin/env bash
set -euo pipefail

MODEL="${KATAGO_MODEL:-/models/latest.bin.gz}"
CFG="/opt/katago/analysis.cfg"
PORT="${KATAGO_PORT:-2388}"

if [ ! -f "$MODEL" ]; then
  echo "Model not found at $MODEL"; ls -l /models || true; exit 1
fi

REAL_MODEL="$(readlink -f "$MODEL")"

if [[ "${REAL_MODEL}" != /models/* ]]; then
  echo "Model file must live under /models. Found: ${REAL_MODEL}"; exit 1
fi

if [[ ! "$(basename "$REAL_MODEL")" =~ ^kata1.*\.bin\.gz$ ]]; then
  echo "Incompatible network detected: $(basename "$REAL_MODEL")"; exit 1
fi

if ! gzip -t "$REAL_MODEL"; then
  echo "Network file $(basename "$REAL_MODEL") failed gzip integrity check"; exit 1
fi

echo "Starting KataGo analysis @ 0.0.0.0:${PORT} with model $REAL_MODEL"
exec /opt/katago/katago analysis \
  -model "$REAL_MODEL" \
  -config "$CFG" \
  -analysis-threads 2 \
  -analysis-addr "0.0.0.0:${PORT}"
