#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

cd "${SCRIPT_DIR}/.."

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export GIT_SHA_SHORT="${GIT_SHA_SHORT:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"

PYTHON_BIN="${PYTHON_BIN:-python3}"

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "${PYTHON_BIN} is required to launch the KataGo service." >&2
  exit 1
fi

echo "Running serve.py self-test before launching the runner..."
if ! "${PYTHON_BIN}" ./serve.py --selftest; then
  echo "serve.py --selftest failed; fix the reported issues before launching the service." >&2
  exit 1
fi

exec "${SCRIPT_DIR}/native_run.sh"
