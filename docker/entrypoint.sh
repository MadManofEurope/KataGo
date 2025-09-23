#!/usr/bin/env bash
set -euo pipefail

MODEL="${KATAGO_MODEL:-/models/latest.bin.gz}"
CFG=""
CONTAINER_PORT="${KATAGO_CONTAINER_PORT:-2388}"
HOST_PORT="${KATAGO_PORT:-${CONTAINER_PORT}}"

validate_positive_integer() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[0-9]+$ ]] || [ "$value" -le 0 ]; then
    echo "${name} must be a positive integer. Got: ${value}" >&2
    exit 1
  fi
}

OVERRIDE_ARGS=()

if [[ -n "${KATAGO_VISITS:-}" ]]; then
  validate_positive_integer "KATAGO_VISITS" "${KATAGO_VISITS}"
  OVERRIDE_ARGS+=(-override-config "maxVisits=${KATAGO_VISITS}")
fi

if [[ -n "${KATAGO_SEARCH_THREADS:-}" ]]; then
  validate_positive_integer "KATAGO_SEARCH_THREADS" "${KATAGO_SEARCH_THREADS}"
  OVERRIDE_ARGS+=(-override-config "numSearchThreadsPerAnalysisThread=${KATAGO_SEARCH_THREADS}")
fi

if [[ -n "${KATAGO_ANALYSIS_THREADS:-}" ]]; then
  validate_positive_integer "KATAGO_ANALYSIS_THREADS" "${KATAGO_ANALYSIS_THREADS}"
  OVERRIDE_ARGS+=(-override-config "numAnalysisThreads=${KATAGO_ANALYSIS_THREADS}")
fi

if [[ -n "${KATAGO_CONFIG:-}" ]] && [ -f "${KATAGO_CONFIG}" ]; then
  CFG="${KATAGO_CONFIG}"
elif [ -f /config/analysis.cfg ]; then
  CFG="/config/analysis.cfg"
elif [ -f /opt/katago/analysis.cfg ]; then
  CFG="/opt/katago/analysis.cfg"
fi

if [[ -z "${CFG}" ]]; then
  echo "No KataGo analysis configuration file found. Set KATAGO_CONFIG or bind /config/analysis.cfg." >&2
  exit 1
fi

if [[ -z "${MODEL}" ]]; then
  echo "KATAGO_MODEL is not set." >&2
  exit 1
fi

if [ ! -f "$MODEL" ]; then
  echo "Model not found at $MODEL"
  ls -l /models || true
  exit 1
fi

if [ ! -f "$CFG" ]; then
  echo "Config not found at $CFG" >&2
  ls -l "$(dirname "$CFG")" || true
  exit 1
fi

REAL_MODEL="$(readlink -f "$MODEL")"
REAL_CFG="$(readlink -f "$CFG")"

if [[ "${REAL_MODEL}" != /models/* ]]; then
  echo "Model file must live under /models. Found: ${REAL_MODEL}"
  exit 1
fi

if [[ "${REAL_CFG}" != /config/* && "${REAL_CFG}" != /opt/katago/* ]]; then
  echo "Config file must be under /config or /opt/katago. Found: ${REAL_CFG}" >&2
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

echo "Starting KataGo analysis @ 0.0.0.0:${CONTAINER_PORT} (host port ${HOST_PORT}) with model $REAL_MODEL and config $REAL_CFG"

CMD=(
  /opt/katago/katago
  analysis
  -model "$REAL_MODEL"
  -config "$REAL_CFG"
)

if ((${#OVERRIDE_ARGS[@]})); then
  CMD+=("${OVERRIDE_ARGS[@]}")
fi

printf -v KATAGO_CMD '%q ' "${CMD[@]}"
KATAGO_CMD="${KATAGO_CMD% }"

SOCAT_ARGS=(
  "TCP-LISTEN:${CONTAINER_PORT},reuseaddr,fork"
  "EXEC:${KATAGO_CMD}"
)

exec socat "${SOCAT_ARGS[@]}"
