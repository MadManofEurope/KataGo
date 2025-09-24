#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="${ROOT_DIR}/.bin"
MODELS_DIR="${ROOT_DIR}/models"
CONFIG_DIR="${ROOT_DIR}/config"
CONFIG_TEMPLATE="${CONFIG_DIR}/analysis.cfg.template"
CONFIG_PATH="${CONFIG_DIR}/analysis.cfg"
ZIP_URL="https://github.com/lightvector/KataGo/releases/download/v1.16.3/KataGo-v1.16.3-cuda12.5-linux-x64.zip"
ZIP_PATH="${BIN_DIR}/KataGo-v1.16.3-cuda12.5-linux-x64.zip"
APPIMAGE_PATH="${BIN_DIR}/katago"
EXTRACTED_BIN="${BIN_DIR}/katago.bin"

mkdir -p "${BIN_DIR}" "${MODELS_DIR}" "${CONFIG_DIR}"

if [[ -f "${CONFIG_TEMPLATE}" && ! -f "${CONFIG_PATH}" ]]; then
  cp "${CONFIG_TEMPLATE}" "${CONFIG_PATH}"
fi

if [[ -x "${APPIMAGE_PATH}" ]] && "${APPIMAGE_PATH}" --version >/dev/null 2>&1; then
  exit 0
fi

echo "Installing KataGo v1.16.3 (CUDA12.5) into ${BIN_DIR}" >&2

if [[ ! -f "${ZIP_PATH}" ]]; then
  tmp_zip="${ZIP_PATH}.tmp"
  echo "Downloading KataGo release zip..." >&2
  curl -fL "${ZIP_URL}" -o "${tmp_zip}"
  mv "${tmp_zip}" "${ZIP_PATH}"
fi

unzip -o "${ZIP_PATH}" -d "${BIN_DIR}" >/dev/null

appimage_source="$(find "${BIN_DIR}" -maxdepth 1 -type f -name '*.AppImage' | head -n1)"
if [[ -z "${appimage_source}" ]]; then
  echo "Failed to locate AppImage after unzip. Contents:" >&2
  ls -al "${BIN_DIR}" >&2
  exit 1
fi

mv -f "${appimage_source}" "${APPIMAGE_PATH}"
chmod +x "${APPIMAGE_PATH}"

pushd "${ROOT_DIR}" >/dev/null
"${APPIMAGE_PATH}" --appimage-extract || true
if [[ -f "squashfs-root/usr/bin/katago" ]]; then
  mv -f "squashfs-root/usr/bin/katago" "${EXTRACTED_BIN}"
  chmod +x "${EXTRACTED_BIN}"
  rm -rf "squashfs-root"
  ln -sfn "katago.bin" "${APPIMAGE_PATH}"
fi
popd >/dev/null

if ! "${APPIMAGE_PATH}" --version >/dev/null 2>&1; then
  echo "KataGo binary at ${APPIMAGE_PATH} failed to run. Check installation." >&2
  exit 1
fi
