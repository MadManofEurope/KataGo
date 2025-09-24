#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SCRIPT="${ROOT_DIR}/scripts/native_install.sh"
MODEL_SCRIPT="${ROOT_DIR}/scripts/01_get_model.sh"
KATAGO_BIN="${ROOT_DIR}/.bin/katago"
MODEL_PATH="${ROOT_DIR}/models/latest.bin.gz"
CONFIG_PATH="${KATAGO_CONFIG:-${ROOT_DIR}/config/analysis.cfg}"
HOST="127.0.0.1"
PORT="2388"

"${INSTALL_SCRIPT}"

if ! "${MODEL_SCRIPT}"; then
  echo "Failed to ensure KataGo model via ${MODEL_SCRIPT}." >&2
  exit 1
fi

if [[ ! -f "${MODEL_PATH}" ]]; then
  echo "KataGo model not found at ${MODEL_PATH} after running ${MODEL_SCRIPT}." >&2
  echo "Set KATAGO_MODEL_URL or check CI_MOCK_MODEL usage." >&2
  exit 1
fi

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "Configuration file not found at ${CONFIG_PATH}." >&2
  echo "Re-run ./scripts/native_install.sh or set KATAGO_CONFIG to an existing file." >&2
  exit 1
fi

echo "Using KataGo config: ${CONFIG_PATH}"

PYTHON_BIN="${PYTHON_BIN:-python3}"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}

handle_signal() {
  cleanup
  exit 0
}

trap handle_signal INT TERM
trap cleanup EXIT

"${PYTHON_BIN}" "${ROOT_DIR}/serve.py" \
  --host "${HOST}" \
  --port "${PORT}" \
  --katago "${KATAGO_BIN}" \
  --model "${MODEL_PATH}" \
  --config "${CONFIG_PATH}" &
SERVER_PID=$!

wait "${SERVER_PID}"
