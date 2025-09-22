#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
if [[ ! -f "${COMPOSE_FILE}" ]]; then
  if [[ -f "compose.yaml" ]]; then
    echo "Warning: ${COMPOSE_FILE} not found, falling back to compose.yaml" >&2
    COMPOSE_FILE="compose.yaml"
  else
    echo "Error: ${COMPOSE_FILE} not found." >&2
    exit 1
  fi
fi

MODEL_PATH="${KATAGO_MODEL_PATH:-models/latest.bin.gz}"
if [[ ! "${MODEL_PATH}" = /* ]]; then
  MODEL_PATH="${ROOT_DIR}/${MODEL_PATH}"
fi

MODEL_BASENAME="$(basename "${MODEL_PATH}")"
MODEL_DIR="$(dirname "${MODEL_PATH}")"

if [[ "${MODEL_BASENAME}" != *.bin.gz ]]; then
  echo "Error: KataGo model must be a .bin.gz file (got: ${MODEL_BASENAME})." >&2
  exit 1
fi

if [[ ! -f "${MODEL_PATH}" ]]; then
  cat >&2 <<EOF
Error: KataGo model file not found at '${MODEL_PATH}'.

Run './scripts/01_get_model.sh' to download the latest network or set
KATAGO_MODEL_PATH to point to an existing kata1*.bin.gz file.
EOF
  exit 1
fi

CONFIG_PATH="${KATAGO_CONFIG_PATH:-config/analysis.cfg}"
if [[ ! "${CONFIG_PATH}" = /* ]]; then
  CONFIG_PATH="${ROOT_DIR}/${CONFIG_PATH}"
fi

CONFIG_DIR="$(dirname "${CONFIG_PATH}")"

if [[ ! -f "${CONFIG_PATH}" ]]; then
  cat >&2 <<EOF
Error: KataGo analysis config not found at '${CONFIG_PATH}'.

Create one (for example by copying docker/analysis.cfg) or set
KATAGO_CONFIG_PATH to an existing config file before starting the stack.
EOF
  exit 1
fi

PORT="${KATAGO_PORT:-2388}"
SERVICE_NAME="${KATAGO_SERVICE_NAME:-katago}"

IMAGE_TAG="${KATAGO_IMAGE_TAG:-$(git rev-parse --short HEAD)}"

export KATAGO_MODEL_PATH="${MODEL_PATH}"
export KATAGO_MODEL_FILE="${MODEL_BASENAME}"
export KATAGO_MODEL_DIR="${MODEL_DIR}"
export KATAGO_CONFIG_PATH="${CONFIG_PATH}"
export KATAGO_CONFIG_FILE="$(basename "${CONFIG_PATH}")"
export KATAGO_CONFIG_DIR="${CONFIG_DIR}"
export KATAGO_PORT="${PORT}"
export KATAGO_IMAGE="katago-json:${IMAGE_TAG}"

echo "Starting KataGo using ${COMPOSE_FILE} with image ${KATAGO_IMAGE}..."
docker compose -f "${COMPOSE_FILE}" up -d

echo "Streaming logs from service '${SERVICE_NAME}' (Ctrl+C to stop)..."
docker compose -f "${COMPOSE_FILE}" logs -f "${SERVICE_NAME}"
