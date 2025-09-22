#!/usr/bin/env bash
set -euo pipefail

MODEL="${KATAGO_MODEL:-/models/latest.bin.gz}"
CFG_TEMPLATE="/opt/katago/analysis.cfg.tmpl"
CFG="/opt/katago/analysis.cfg"
PORT="${KATAGO_PORT:-2388}"
THREADS="${KATAGO_ANALYSIS_THREADS:-8}"

if [ ! -f "$MODEL" ]; then
  echo "Model not found at $MODEL"
  ls -l /models || true
  exit 1
fi

REAL_MODEL="$(readlink -f "$MODEL")"

if [[ "${REAL_MODEL}" != /models/* ]]; then
  echo "Model file must live under /models. Found: ${REAL_MODEL}"
  exit 1
fi

if [[ ! "$(basename "$REAL_MODEL")" =~ ^kata1.*\.bin\.gz$ ]]; then
  echo "Incompatible network detected: $(basename "$REAL_MODEL")"
  exit 1
fi

if ! gzip -t "$REAL_MODEL"; then
  echo "Network file $(basename "$REAL_MODEL") failed gzip integrity check"
  exit 1
fi

# Check for NVIDIA GPU devices
if ! compgen -G "/dev/nvidia*" >/dev/null 2>&1; then
  if ! command -v nvidia-smi >/dev/null 2>&1 || ! nvidia-smi >/dev/null 2>&1; then
    echo "No NVIDIA devices detected. Ensure the NVIDIA Container Toolkit / GPU runtime is installed and the container is started with GPU access." >&2
    exit 1
  else
    echo "nvidia-smi found but /dev/nvidia* devices missing; GPU device nodes may not be exposed."
    exit 1
  fi
fi

if [ ! -f "$CFG_TEMPLATE" ]; then
  echo "Config template not found at $CFG_TEMPLATE" >&2
  exit 1
fi

CONFIG_CONTENT="$(cat "$CFG_TEMPLATE")"
eval "cat <<EOF
$CONFIG_CONTENT
EOF" > "$CFG"

echo "Starting KataGo analysis @ 0.0.0.0:${PORT} with model $REAL_MODEL"

exec /opt/katago/katago analysis \
  -model "$REAL_MODEL" \
  -config "$CFG" \
  -analysis-threads "$THREADS" \
  -analysis-addr "0.0.0.0:${PORT}"
