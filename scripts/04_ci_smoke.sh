#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
HOST_ADDR="${HOST_ADDR:-127.0.0.1}"
PORT="${PORT:-2388}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-60}"

if [[ ! "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -le 0 ]; then
  echo "PORT must be a positive integer. Got: ${PORT}" >&2
  exit 1
fi

if [[ ! "$HEALTH_TIMEOUT" =~ ^[0-9]+$ ]] || [ "$HEALTH_TIMEOUT" -le 0 ]; then
  echo "HEALTH_TIMEOUT must be a positive integer. Got: ${HEALTH_TIMEOUT}" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to probe the KataGo JSON endpoint." >&2
  exit 1
fi

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "${PYTHON_BIN} is required to launch the KataGo service." >&2
  exit 1
fi

KATAGO_BIN="${ROOT_DIR}/.bin/katago"
MODEL_PATH="${ROOT_DIR}/models/latest.bin.gz"
CONFIG_PATH="${KATAGO_CONFIG:-${ROOT_DIR}/config/analysis.cfg}"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

payload='{"id":"ping","action":"query_version"}'

"${SCRIPT_DIR}/native_install.sh"
"${SCRIPT_DIR}/01_get_model.sh"

"${PYTHON_BIN}" "${ROOT_DIR}/serve.py" \
  --host "${HOST_ADDR}" \
  --port "${PORT}" \
  --katago "${KATAGO_BIN}" \
  --model "${MODEL_PATH}" \
  --config "${CONFIG_PATH}" &
SERVER_PID=$!

start_time=$(date +%s)

printf 'Waiting for KataGo JSON service to become healthy'
while true; do
  if curl -fsS "http://${HOST_ADDR}:${PORT}" \
    -H 'Content-Type: application/json' \
    -d "${payload}" >/dev/null; then
    echo " - healthy"
    break
  fi

  if (( $(date +%s) - start_time >= HEALTH_TIMEOUT )); then
    echo
    echo "KataGo JSON API did not become ready within ${HEALTH_TIMEOUT} seconds" >&2
    exit 1
  fi

  printf '.'
  sleep 2
done

echo "KataGo JSON API responded successfully"
