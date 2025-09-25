#!/usr/bin/env bash
set -euo pipefail

: "${KATAGO_CONFIG:=/config/analysis.cfg}"
MODEL_LINK="/models/latest.bin.gz"
MODEL="${KATAGO_MODEL:-${MODEL_LINK}}"

if [[ -z "${KATAGO_CONFIG}" ]]; then
  echo "KATAGO_CONFIG is set but empty; provide a path to a configuration file." >&2
  exit 1
fi

if [[ ! -f "${KATAGO_CONFIG}" ]]; then
  echo "Missing config: ${KATAGO_CONFIG}" >&2
  exit 1
fi

if [[ ! -f "${MODEL_LINK}" ]]; then
  echo "Missing model: ${MODEL_LINK}" >&2
  exit 1
fi

if ! ldconfig -p | grep -q libcudnn; then
  echo "Warning: libcudnn not visible via ldconfig; proceeding because the base image includes cuDNN." >&2
fi

CFG="${KATAGO_CONFIG}"
PORT="${PORT:-2388}"
LISTEN_ADDR="${KATAGO_LISTEN:-0.0.0.0}"

validate_positive_integer() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[0-9]+$ ]] || [ "$value" -le 0 ]; then
    echo "${name} must be a positive integer. Got: ${value}" >&2
    exit 1
  fi
}

CONFIG_OVERRIDES=("allowResignation=false")

NN_MAX_BATCH_SIZE="${KATAGO_NN_MAX_BATCH_SIZE:-32}"
if [[ -n "${NN_MAX_BATCH_SIZE}" ]]; then
  validate_positive_integer "KATAGO_NN_MAX_BATCH_SIZE" "${NN_MAX_BATCH_SIZE}"
  CONFIG_OVERRIDES+=("nnMaxBatchSize=${NN_MAX_BATCH_SIZE}")
fi

if [[ -n "${KATAGO_VISITS:-}" ]]; then
  validate_positive_integer "KATAGO_VISITS" "${KATAGO_VISITS}"
  CONFIG_OVERRIDES+=("maxVisits=${KATAGO_VISITS}")
fi

if [[ -n "${KATAGO_SEARCH_THREADS:-}" ]]; then
  validate_positive_integer "KATAGO_SEARCH_THREADS" "${KATAGO_SEARCH_THREADS}"
  CONFIG_OVERRIDES+=("numSearchThreadsPerAnalysisThread=${KATAGO_SEARCH_THREADS}")
fi

if [[ -n "${KATAGO_ANALYSIS_THREADS:-}" ]]; then
  validate_positive_integer "KATAGO_ANALYSIS_THREADS" "${KATAGO_ANALYSIS_THREADS}"
  CONFIG_OVERRIDES+=("numAnalysisThreads=${KATAGO_ANALYSIS_THREADS}")
fi

if [[ -z "${MODEL}" ]]; then
  echo "KATAGO_MODEL is not set." >&2
  exit 1
fi

if [[ ! -f "${MODEL}" ]]; then
  echo "Model not found at ${MODEL}" >&2
  exit 1
fi

REAL_MODEL="$(readlink -f "$MODEL")"
REAL_CFG="$(readlink -f "$CFG")"
echo "Using KataGo analysis config: ${REAL_CFG}" >&2

if [[ "${REAL_MODEL}" != /models/* ]]; then
  echo "Model file must live under /models. Found: ${REAL_MODEL}" >&2
  exit 1
fi

if [[ "${REAL_CFG}" != /config/* && "${REAL_CFG}" != /opt/katago/* ]]; then
  echo "Config file must be under /config or /opt/katago. Found: ${REAL_CFG}" >&2
  exit 1
fi

if [[ ! "$(basename "$REAL_MODEL")" =~ ^kata1.*\.bin\.gz$ ]]; then
  echo "Incompatible network detected: $(basename "$REAL_MODEL")" >&2
  exit 1
fi

if ! gzip -t "$REAL_MODEL"; then
  echo "Network file $(basename "$REAL_MODEL") failed gzip integrity check" >&2
  exit 1
fi

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi command not found; ensure NVIDIA Container Toolkit is configured." >&2
  exit 1
fi

if ! nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi failed; GPU may be unavailable. Verify GPU access." >&2
  exit 1
fi

validate_positive_integer "PORT" "${PORT}"

echo "Starting KataGo analysis @ ${LISTEN_ADDR}:${PORT} with model ${REAL_MODEL} and config ${REAL_CFG}" >&2

PROXY_ARGS=(
  --listen "${LISTEN_ADDR}"
  --port "${PORT}"
  --katago /opt/katago/katago
  --model "${REAL_MODEL}"
  --config "${REAL_CFG}"
)

for override in "${CONFIG_OVERRIDES[@]}"; do
  PROXY_ARGS+=(--override-config "${override}")
done

exec python3 /opt/katago/serve.py "${PROXY_ARGS[@]}"
