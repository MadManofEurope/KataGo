#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SERVICE_SRC="${ROOT_DIR}/systemd/user/katago-json.service"
SERVICE_DEST="${HOME}/.config/systemd/user/katago-json.service"

if [ ! -f "${SERVICE_SRC}" ]; then
  echo "Service template missing at ${SERVICE_SRC}." >&2
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemctl is required to manage user services." >&2
  exit 1
fi

if ! systemctl --user show-environment >/dev/null 2>&1; then
  echo "systemd --user is unavailable. Ensure you are logged into a systemd user session." >&2
  exit 1
fi

mkdir -p "${HOME}/.config/systemd/user"
cp "${SERVICE_SRC}" "${SERVICE_DEST}"

systemctl --user daemon-reload
systemctl --user enable --now katago-json.service

echo "Enabled katago-json.service as a user service."
