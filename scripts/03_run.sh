#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

MODEL_FILE="${KATAGO_MODEL_FILE:-latest.bin.gz}"
MODEL_PATH="models/${MODEL_FILE}"

# Require a gzip’d KataGo network file name.
if [[ "${MODEL_FILE}" != *.bin.gz ]]; then
  echo "Error: KATAGO_MODEL_FILE must point to a .bin.gz file (got: ${MODEL_FILE})." >&2
  echo "Please double-check the model filename and try again." >&2
  exit 1
fi

# Ensure the model file exists before starting the container.
if [[ ! -f "${MODEL_PATH}" ]]; then
  cat >&2 <<EOF
Error: KataGo model file not found at '${MODEL_PATH}'.

Download the desired model (e.g. by running './scripts/01_get_model.sh')
so that '${MODEL_PATH}' exists before launching the containers.
EOF
  exit 1
fi

# Bring up the analysis server and follow logs.
docker compose up -d
docker logs -f katago-analysis
