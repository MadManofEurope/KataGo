#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "${ROOT_DIR}/config" "${ROOT_DIR}/models"

if [ ! -f "${ROOT_DIR}/config/analysis.cfg" ]; then
  cp "${ROOT_DIR}/docker/analysis.cfg" "${ROOT_DIR}/config/analysis.cfg"
  echo "Copied docker/analysis.cfg to config/analysis.cfg. Customize as needed."
fi

echo "Ensured config/ and models/ exist. Run ./scripts/01_get_model.sh to download a kata1 network."
