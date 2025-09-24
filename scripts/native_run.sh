#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SCRIPT="${ROOT_DIR}/scripts/native_install.sh"
KATAGO_BIN="${ROOT_DIR}/.bin/katago"
MODEL_PATH="${ROOT_DIR}/models/latest.bin.gz"
CONFIG_PATH="${KATAGO_CONFIG:-${ROOT_DIR}/config/analysis.cfg}"
HOST="127.0.0.1"
PORT="2388"

"${INSTALL_SCRIPT}"

PYTHON_BIN="${PYTHON_BIN:-python3}"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    kill "${SERVER_PID}"
    wait "${SERVER_PID}" || true
  fi
}

trap cleanup INT TERM
trap 'cleanup; exit' EXIT

set +e
"${PYTHON_BIN}" "${ROOT_DIR}/serve.py" \
  --host "${HOST}" \
  --port "${PORT}" \
  --katago "${KATAGO_BIN}" \
  --model "${MODEL_PATH}" \
  --config "${CONFIG_PATH}" &
SERVER_PID=$!
set -e

wait "${SERVER_PID}"
