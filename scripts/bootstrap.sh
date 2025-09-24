#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_GIT="${ROOT_DIR}/.git"

resolve_path() {
  local target="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target" 2>/dev/null || echo '(unresolved)'
  elif command -v readlink >/dev/null 2>&1; then
    readlink -f "$target" 2>/dev/null || echo '(unresolved)'
  else
    echo '(unresolved)'
  fi
}

if [[ -d "${HOME}/KataGo" && ! -d "${HOME}/KataGo/.git" ]]; then
  echo "Found ${HOME}/KataGo without a Git checkout. Move or delete it, then rerun ./scripts/bootstrap.sh." >&2
  exit 2
fi

if [[ ! -d "${REPO_GIT}" ]]; then
  echo "This script must be run inside a Git checkout of KataGo." >&2
  exit 2
fi

echo "[bootstrap] Ensuring KataGo binary is installed..."
"${SCRIPT_DIR}/native_install.sh"

echo "[bootstrap] Ensuring KataGo model is available..."
"${SCRIPT_DIR}/01_get_model.sh"

KATAGO_BIN="${ROOT_DIR}/.bin/katago"
MODEL_LINK="${ROOT_DIR}/models/latest.bin.gz"
CONFIG_PATH="${KATAGO_CONFIG:-${ROOT_DIR}/config/analysis.cfg}"

resolved_model="$(resolve_path "${MODEL_LINK}")"

echo "[bootstrap] Ready to launch server with:"
echo "  KataGo binary : ${KATAGO_BIN}"
echo "  Model symlink : ${MODEL_LINK} -> ${resolved_model}"
echo "  Config file   : ${CONFIG_PATH}"

echo "[bootstrap] Starting native JSON server..."
exec "${SCRIPT_DIR}/native_run.sh"
