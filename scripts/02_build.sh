#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

cd "${SCRIPT_DIR}/.."

GIT_SHA_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
export GIT_SHA_SHORT

echo "Refreshing KataGo binary and configuration..."
"${SCRIPT_DIR}/native_install.sh"

echo "Refreshing KataGo model bundle..."
"${SCRIPT_DIR}/01_get_model.sh"
