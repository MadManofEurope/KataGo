#!/usr/bin/env bash
# Fetch the latest kata1 network and link it as models/latest.bin.gz.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODELS_DIR="${ROOT_DIR}/models"
DEFAULT_MODEL_URL="https://media.katagotraining.org/uploaded/networks/models/kata1/kata1-b28c512nbt-s10964269312-d5332792958.bin.gz"
MODEL_URL="${KATAGO_MODEL_URL:-${1:-${DEFAULT_MODEL_URL}}}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd curl
require_cmd gzip

mkdir -p "${MODELS_DIR}"

if [[ "${CI_MOCK_MODEL:-0}" == "1" ]]; then
  mock_model="${MODELS_DIR}/kata1-mock.bin.gz"
  tmp_mock="${mock_model}.tmp"
  printf 'mock-katago-model\n' | gzip -c >"${tmp_mock}"
  mv "${tmp_mock}" "${mock_model}"
  ln -sfn "$(basename "${mock_model}")" "${MODELS_DIR}/latest.bin.gz"
  echo "Using CI mock KataGo model" >&2
  exit 0
fi

find_existing_model() {
  find "${MODELS_DIR}" -maxdepth 1 -type f -name '*.bin.gz' ! -name 'latest.bin.gz' | sort | head -n1
}

validate_model() {
  local path="$1"
  if [[ -z "${path}" ]]; then
    return 1
  fi
  if gzip -t "${path}" >/dev/null 2>&1; then
    echo "Using existing kata1 network: $(basename "${path}")" >&2
    printf '%s' "${path}"
    return 0
  fi
  echo "Existing model ${path} failed gzip integrity check and will be removed." >&2
  rm -f "${path}"
  return 1
}

download_model() {
  local url="$1"
  local filename="${url##*/}"
  if [[ "${filename}" != *.bin.gz ]]; then
    echo "Model URL must point to a .bin.gz file: ${url}" >&2
    exit 1
  fi
  local dest="${MODELS_DIR}/${filename}"
  if [[ -f "${dest}" ]]; then
    if validate_model "${dest}" >/dev/null; then
      printf '%s' "${dest}"
      return 0
    fi
  fi
  local tmp="${dest}.tmp"
  echo "Downloading $(basename "${dest}")" >&2
  curl -fL "${url}" -o "${tmp}"
  mv "${tmp}" "${dest}"
  if ! gzip -t "${dest}" >/dev/null 2>&1; then
    echo "Downloaded model failed gzip integrity check: ${dest}" >&2
    rm -f "${dest}" "${tmp}" >&2
    exit 1
  fi
  printf '%s' "${dest}"
}

existing_model="$(find_existing_model)"
if ! model_path="$(validate_model "${existing_model}")"; then
  model_path="$(download_model "${MODEL_URL}")"
fi

ln -sfn "$(basename "${model_path}")" "${MODELS_DIR}/latest.bin.gz"
echo "Linked $(basename "${model_path}") to models/latest.bin.gz" >&2
