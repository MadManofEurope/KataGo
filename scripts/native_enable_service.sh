#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_SRC="${ROOT_DIR}/systemd/user/katago-json.service"
SERVICE_DEST="${HOME}/.config/systemd/user/katago-json.service"

if [ ! -f "${SERVICE_SRC}" ]; then
  echo "Service template missing at ${SERVICE_SRC}." >&2
  exit 1
fi

mkdir -p "${HOME}/.config/systemd/user"
cp "${SERVICE_SRC}" "${SERVICE_DEST}"

systemctl --user daemon-reload
systemctl --user enable --now katago-json.service

echo "Enabled katago-json.service as a user service."
