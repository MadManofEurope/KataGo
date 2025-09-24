#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KATAGO_BIN="${ROOT_DIR}/.bin/katago"
MODEL_PATH="${ROOT_DIR}/models/latest.bin.gz"
CONFIG_PATH="${KATAGO_CONFIG:-${ROOT_DIR}/config/analysis.cfg}"
HOST="127.0.0.1"
PORT="2388"

if [ ! -x "${KATAGO_BIN}" ]; then
  echo "KataGo binary not found at ${KATAGO_BIN}. Run ./scripts/native_install_plucky.sh first." >&2
  exit 1
fi

if [ ! -f "${MODEL_PATH}" ]; then
  echo "Model file ${MODEL_PATH} is missing. Run ./scripts/01_get_model.sh." >&2
  exit 1
fi

if [ ! -f "${CONFIG_PATH}" ]; then
  echo "Config file ${CONFIG_PATH} is missing. Set KATAGO_CONFIG or run ./scripts/00_setup_dirs.sh." >&2
  exit 1
fi

echo "Using config: ${CONFIG_PATH}"

PYTHON_BIN="${PYTHON_BIN:-python3}"

set +e
"${PYTHON_BIN}" "${ROOT_DIR}/serve.py" \
  --host "${HOST}" \
  --port "${PORT}" \
  --katago "${KATAGO_BIN}" \
  --model "${MODEL_PATH}" \
  --config "${CONFIG_PATH}" &
SERVER_PID=$!
set -e

cleanup() {
  if kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    kill "${SERVER_PID}"
    wait "${SERVER_PID}" || true
  fi
}

trap cleanup INT TERM EXIT
wait "${SERVER_PID}"
