#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
KATAGO_BIN="${KATAGO_BIN:-${ROOT_DIR}/.bin/katago}"
MODEL_DEFAULT="${ROOT_DIR}/models/latest.bin.gz"
CONFIG_DEFAULT="${ROOT_DIR}/config/analysis.cfg"

normalize_path() {
  local path="$1"
  case "$path" in
    ~/*)
      path="${HOME}/${path:2}"
      ;;
    ~)
      path="${HOME}"
      ;;
  esac
  if [[ "$path" != /* ]]; then
    path="${ROOT_DIR}/${path}"
  fi
  printf '%s\n' "$path"
}

if [[ "${KATAGO_MODEL+x}" == "x" ]]; then
  if [[ -z "${KATAGO_MODEL}" ]]; then
    echo "KATAGO_MODEL is set but empty; provide a path to a KataGo model." >&2
    exit 1
  fi
  MODEL="${KATAGO_MODEL}"
else
  MODEL="${MODEL_DEFAULT}"
fi

if [[ "${KATAGO_CONFIG+x}" == "x" ]]; then
  if [[ -z "${KATAGO_CONFIG}" ]]; then
    echo "KATAGO_CONFIG is set but empty; provide a path to a configuration file." >&2
    exit 1
  fi
  CFG="${KATAGO_CONFIG}"
else
  CFG="${CONFIG_DEFAULT}"
fi

MODEL="$(normalize_path "${MODEL}")"
CFG="$(normalize_path "${CFG}")"
KATAGO_BIN="$(normalize_path "${KATAGO_BIN}")"

PORT="${PORT:-${KATAGO_PORT:-2388}}"
LISTEN_ADDR="${KATAGO_LISTEN:-127.0.0.1}"

validate_positive_integer() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[0-9]+$ ]] || [ "$value" -le 0 ]; then
    echo "${name} must be a positive integer. Got: ${value}" >&2
    exit 1
  fi
}

resolve_path() {
  local target="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target" 2>/dev/null || echo "$target"
  elif command -v readlink >/dev/null 2>&1; then
    readlink -f "$target" 2>/dev/null || echo "$target"
  else
    echo "$target"
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

if [[ ! -x "${KATAGO_BIN}" ]]; then
  echo "KataGo binary not found or not executable at ${KATAGO_BIN}" >&2
  exit 1
fi

if [[ ! -f "${CFG}" ]]; then
  echo "Config not found at ${CFG}" >&2
  exit 1
fi

if [[ ! -f "${MODEL}" ]]; then
  echo "Model not found at ${MODEL}" >&2
  exit 1
fi

if [[ ! -r "${MODEL}" ]]; then
  echo "Model at ${MODEL} is not readable." >&2
  exit 1
fi

if [[ ! -r "${CFG}" ]]; then
  echo "Config at ${CFG} is not readable." >&2
  exit 1
fi

REAL_MODEL="$(resolve_path "${MODEL}")"
REAL_CFG="$(resolve_path "${CFG}")"
REAL_BIN="$(resolve_path "${KATAGO_BIN}")"

if [[ ! "$(basename "$REAL_MODEL")" =~ ^kata1.*\.bin\.gz$ ]]; then
  echo "Incompatible network detected: $(basename "$REAL_MODEL")" >&2
  exit 1
fi

if ! command -v gzip >/dev/null 2>&1; then
  echo "gzip is required to validate KataGo network archives." >&2
  exit 1
fi

if ! gzip -t "$REAL_MODEL"; then
  echo "Network file $(basename "$REAL_MODEL") failed gzip integrity check" >&2
  exit 1
fi

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi command not found; ensure NVIDIA drivers and CUDA toolkit are installed." >&2
  exit 1
fi

if ! nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi failed; GPU may be unavailable. Verify GPU access." >&2
  exit 1
fi

validate_positive_integer "PORT" "${PORT}"

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "${PYTHON_BIN} is required to launch the KataGo service." >&2
  exit 1
fi

echo "Starting KataGo analysis @ ${LISTEN_ADDR}:${PORT}" >&2

echo "  KataGo binary : ${REAL_BIN}" >&2

echo "  Model file    : ${REAL_MODEL}" >&2

echo "  Config file   : ${REAL_CFG}" >&2

PROXY_ARGS=(
  --host "${LISTEN_ADDR}"
  --port "${PORT}"
  --katago "${REAL_BIN}"
  --model "${REAL_MODEL}"
  --config "${REAL_CFG}"
)

for override in "${CONFIG_OVERRIDES[@]}"; do
  PROXY_ARGS+=(--override-config "${override}")
done

exec "${PYTHON_BIN}" "${ROOT_DIR}/serve.py" "${PROXY_ARGS[@]}"
