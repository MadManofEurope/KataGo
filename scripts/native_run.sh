#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_SCRIPT="${ROOT_DIR}/scripts/native_install.sh"
MODEL_SCRIPT="${ROOT_DIR}/scripts/01_get_model.sh"
KATAGO_BIN="${ROOT_DIR}/.bin/katago"
MODEL_PATH="${ROOT_DIR}/models/latest.bin.gz"
CONFIG_PATH="${KATAGO_CONFIG:-${ROOT_DIR}/config/analysis.cfg}"
HOST="127.0.0.1"
PORT="2388"

resolve_path() {
  local target="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target" 2>/dev/null || echo 'unresolved'
  elif command -v readlink >/dev/null 2>&1; then
    readlink -f "$target" 2>/dev/null || echo 'unresolved'
  else
    echo 'unresolved'
  fi
}

echo "Preparing to start KataGo JSON server on 127.0.0.1:2388"
echo "  KataGo binary : ${KATAGO_BIN} -> $(resolve_path "${KATAGO_BIN}")"
echo "  Model symlink : ${MODEL_PATH} -> $(resolve_path "${MODEL_PATH}")"
echo "  Config file   : ${CONFIG_PATH} -> $(resolve_path "${CONFIG_PATH}")"

if [[ ! -x "${KATAGO_BIN}" ]]; then
  echo "Missing KataGo binary at ${KATAGO_BIN}. Run ${INSTALL_SCRIPT}" >&2
  exit 1
fi

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "Missing KataGo config at ${CONFIG_PATH}. Run ${INSTALL_SCRIPT}" >&2
  exit 1
fi

if [[ ! -r "${CONFIG_PATH}" ]]; then
  echo "KataGo config at ${CONFIG_PATH} is not readable." >&2
  exit 1
fi

if [[ ! -f "${MODEL_PATH}" ]]; then
  echo "Missing KataGo model at ${MODEL_PATH}. Run ${MODEL_SCRIPT}" >&2
  exit 1
fi

if [[ ! -r "${MODEL_PATH}" ]]; then
  echo "KataGo model at ${MODEL_PATH} is not readable." >&2
  exit 1
fi

set +e
analysis_output="$(${KATAGO_BIN} analysis -help 2>&1)"
analysis_status=$?
set -e
if [[ ${analysis_status} -ne 0 ]]; then
  if [[ "${analysis_output}" == *"libzip.so.4"* ]]; then
    echo "Using AppImage avoids libzip issues. Run ./scripts/native_install.sh again." >&2
  fi
  echo "KataGo binary at ${KATAGO_BIN} failed the 'analysis -help' check." >&2
  exit 1
fi

echo "Starting KataGo JSON server on 127.0.0.1:2388"
echo "  KataGo binary : ${KATAGO_BIN}"
echo "  Model symlink : ${MODEL_PATH} -> $(resolve_path "${MODEL_PATH}")"
echo "  Config file   : ${CONFIG_PATH}"

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
