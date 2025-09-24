#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "${ROOT_DIR}/config" "${ROOT_DIR}/models"

TEMPLATE="${ROOT_DIR}/config/analysis.cfg.template"
DEST="${ROOT_DIR}/config/analysis.cfg"

if [ ! -f "${DEST}" ] && [ -f "${TEMPLATE}" ]; then
  cp "${TEMPLATE}" "${DEST}"
  echo "Seeded config/analysis.cfg from config/analysis.cfg.template. Customize as needed."
fi

echo "Ensured config/ and models/ exist. Run ./scripts/01_get_model.sh to download a kata1 network."
