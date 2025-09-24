#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
KATAGO_BIN="${ROOT_DIR}/.bin/katago"
MODEL_LINK="${ROOT_DIR}/models/latest.bin.gz"
CONFIG_PATH="${KATAGO_CONFIG:-${ROOT_DIR}/config/analysis.cfg}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

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

status=0

branch="$(git -C "${ROOT_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(unknown)")"
commit="$(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || echo "(unknown)")"

echo "Repository: ${branch} @ ${commit}"

diagnose_path() {
  local name="$1"
  local path="$2"
  local check_exec="${3:-0}"

  if [[ ! -e "${path}" ]]; then
    echo "[missing] ${name} not found at ${path}" >&2
    status=1
    return
  fi

  if [[ ! -r "${path}" ]]; then
    echo "[error] ${name} at ${path} is not readable" >&2
    status=1
    return
  fi

  if [[ "${check_exec}" == "1" && ! -x "${path}" ]]; then
    echo "[error] ${name} at ${path} is not executable" >&2
    status=1
    return
  fi

  echo "[ok] ${name}: ${path}"
}

diagnose_path "KataGo binary" "${KATAGO_BIN}" 1
resolved_model="$(resolve_path "${MODEL_LINK}")"
diagnose_path "Model symlink" "${MODEL_LINK}"
if [[ -L "${MODEL_LINK}" || -e "${MODEL_LINK}" ]]; then
  echo "      -> ${resolved_model}"
fi

diagnose_path "Config file" "${CONFIG_PATH}"

echo "[doctor] Running serve.py --selftest"
if ! "${PYTHON_BIN}" "${ROOT_DIR}/serve.py" --selftest; then
  status=1
fi

exit "${status}"
