#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${ROOT_DIR}/.bin"
VENV_DIR="${ROOT_DIR}/.venv"
KATAGO_BIN="${BIN_DIR}/katago"
APPIMAGE_PATH="${BIN_DIR}/katago.AppImage"
ZIP_PATH="${BIN_DIR}/katago.zip"
MODEL_PATH="${ROOT_DIR}/models/latest.bin.gz"
CONFIG_PATH="${ROOT_DIR}/config/analysis.cfg"
RELEASE_URL="https://github.com/lightvector/KataGo/releases/download/v1.16.3/katago-v1.16.3-cuda12.5-cudnn8.9.7-linux-x64.zip"

mkdir -p "${BIN_DIR}" "${VENV_DIR}"

if [ ! -f "${CONFIG_PATH}" ]; then
  echo "Missing ${CONFIG_PATH}. Run ./scripts/00_setup_dirs.sh to create it." >&2
  exit 1
fi

if [ ! -f "${MODEL_PATH}" ]; then
  echo "Missing ${MODEL_PATH}. Run ./scripts/01_get_model.sh to download a network." >&2
  exit 1
fi

if [ -x "${KATAGO_BIN}" ]; then
  if "${KATAGO_BIN}" --version >/dev/null 2>&1; then
    echo "KataGo already installed at ${KATAGO_BIN}."
    exit 0
  else
    echo "Existing ${KATAGO_BIN} is not functional. Reinstalling." >&2
    rm -f "${KATAGO_BIN}"
  fi
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to download KataGo." >&2
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip is required to extract KataGo." >&2
  exit 1
fi

tmp_zip="${ZIP_PATH}.tmp"

if [ ! -f "${ZIP_PATH}" ]; then
  echo "Downloading KataGo v1.16.3 CUDA12.5 AppImage..." >&2
  curl -fL "${RELEASE_URL}" -o "${tmp_zip}"
  mv -f "${tmp_zip}" "${ZIP_PATH}"
else
  echo "Using cached ${ZIP_PATH}." >&2
fi

tmp_extract_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_extract_dir}"' EXIT

unzip -o "${ZIP_PATH}" -d "${tmp_extract_dir}" >&2

extracted_appimage="${tmp_extract_dir}/katago"
if [ ! -f "${extracted_appimage}" ]; then
  echo "Expected katago AppImage not found after extraction." >&2
  exit 1
fi

mv -f "${extracted_appimage}" "${APPIMAGE_PATH}"
chmod +x "${APPIMAGE_PATH}"

(
  cd "${BIN_DIR}"
  echo "Extracting KataGo AppImage to avoid FUSE dependency..." >&2
  "${APPIMAGE_PATH}" --appimage-extract || true
  if [ -d "squashfs-root" ]; then
    rm -rf katago.AppDir
    mv squashfs-root katago.AppDir
    cat > "${KATAGO_BIN}" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "${DIR}/katago.AppDir/AppRun" "$@"
WRAPPER
    chmod +x "${KATAGO_BIN}"
  else
    echo "AppImage extraction did not produce squashfs-root." >&2
    exit 1
  fi
)

if ! "${KATAGO_BIN}" --version >/dev/null 2>&1; then
  echo "KataGo binary at ${KATAGO_BIN} failed to execute." >&2
  if command -v ldd >/dev/null 2>&1; then
    missing_libs=$(ldd "${BIN_DIR}/katago.AppDir/usr/bin/katago" | awk '/not found/ {print $1}')
    if [ -n "${missing_libs}" ]; then
      echo "Missing shared libraries: ${missing_libs}" >&2
    fi
  fi
  echo "Ensure the CUDA 12.5 runtime (including libcublas) is available and retry." >&2
  exit 1
fi

echo "KataGo v1.16.3 installed at ${KATAGO_BIN}."
