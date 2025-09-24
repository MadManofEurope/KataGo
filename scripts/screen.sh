#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

SUMMARY=""
FAILED=0
PYTHON_BIN="${PYTHON_BIN:-python3}"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_PATH="${ROOT_DIR}/.bin/katago"
MODEL_PATH="${ROOT_DIR}/models/latest.bin.gz"
CONFIG_PATH="${KATAGO_CONFIG:-${ROOT_DIR}/config/analysis.cfg}"
RUNNER_PATH="${ROOT_DIR}/runner.sh"

record() {
  local status="$1"
  local name="$2"
  local hint="${3:-}"
  SUMMARY+="${status}: ${name}"
  if [ -n "$hint" ]; then
    SUMMARY+=" — ${hint}"
  fi
  SUMMARY+="\n"
  if [ "$status" = "FAIL" ]; then
    FAILED=1
  fi
}

print_summary() {
  local exit_code="$1"
  printf '\nSummary:\n'
  printf '%s' "$SUMMARY"
  if [ "$FAILED" -ne 0 ] && [ "$exit_code" -eq 0 ]; then
    exit_code=$FAILED
  fi
  exit "$exit_code"
}
trap 'print_summary $?' EXIT

log() {
  printf '==> %s\n' "$*"
}

ensure_tool() {
  local name="$1"
  local bin="$2"
  local hint="$3"
  if command -v "$bin" >/dev/null 2>&1; then
    log "${name}: $($bin --version 2>&1 | head -n1)"
    record PASS "${name}" "Detected"
  else
    record FAIL "${name}" "$hint"
  fi
}

enforce_file() {
  local label="$1"
  local path="$2"
  local hint="$3"
  if [ -f "$path" ]; then
    record PASS "$label" "$path"
  else
    record FAIL "$label" "$hint"
  fi
}

log "Checking required tooling"
ensure_tool "Git" git "Install git to manage the repository checkout"
ensure_tool "Curl" curl "Install curl for HTTP health probes"
ensure_tool "JQ" jq "Install jq to parse KataGo release metadata"
ensure_tool "Unzip" unzip "Install unzip to extract KataGo bundles"
if command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  log "Python: $(${PYTHON_BIN} --version 2>&1)"
  record PASS "Python" "${PYTHON_BIN} available"
else
  record FAIL "Python" "Install ${PYTHON_BIN} to run serve.py"
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  log "nvidia-smi output:"
  nvidia-smi | sed 's/^/    /'
  record PASS "NVIDIA driver" "nvidia-smi detected"
else
  record FAIL "NVIDIA driver" "Install NVIDIA drivers compatible with CUDA 12.x"
fi

enforce_file "KataGo binary" "$BIN_PATH" "Run ./scripts/native_install.sh"
enforce_file "Model bundle" "$MODEL_PATH" "Run ./scripts/01_get_model.sh"
enforce_file "Analysis config" "$CONFIG_PATH" "Run ./scripts/native_install.sh"

if [ -f "$RUNNER_PATH" ]; then
  if grep -q 'KATAGO_CONFIG' "$RUNNER_PATH"; then
    record PASS "Runner config" "runner.sh honors KATAGO_CONFIG"
  else
    record FAIL "Runner config" "Ensure runner.sh honors KATAGO_CONFIG"
  fi
else
  record FAIL "Runner script" "runner.sh missing"
fi

if command -v ss >/dev/null 2>&1; then
  log "ss version: $(ss --version 2>&1 | head -n1)"
fi

log "Running serve.py self-test"
if "${PYTHON_BIN}" "${ROOT_DIR}/serve.py" --selftest; then
  record PASS "Self-test" "serve.py --selftest succeeded"
else
  record FAIL "Self-test" "Investigate serve.py --selftest output"
fi
