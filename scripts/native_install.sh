#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="${ROOT_DIR}/.bin"
MODELS_DIR="${ROOT_DIR}/models"
CONFIG_DIR="${ROOT_DIR}/config"
CONFIG_TEMPLATE="${CONFIG_DIR}/analysis.cfg.template"
CONFIG_PATH="${CONFIG_DIR}/analysis.cfg"
ZIP_URL_DEFAULT="https://github.com/lightvector/KataGo/releases/download/v1.16.3/KataGo-v1.16.3-cuda12.5-linux-x64.zip"
ZIP_URL="${KATAGO_RELEASE_URL:-${ZIP_URL_DEFAULT}}"
ZIP_BASENAME="${ZIP_URL##*/}"
ZIP_PATH="${BIN_DIR}/${ZIP_BASENAME}"
APPIMAGE_PATH="${BIN_DIR}/katago"
EXTRACTED_BIN="${BIN_DIR}/katago.bin"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd curl
require_cmd unzip

mkdir -p "${BIN_DIR}" "${MODELS_DIR}" "${CONFIG_DIR}"

if [[ -f "${CONFIG_TEMPLATE}" && ! -f "${CONFIG_PATH}" ]]; then
  cp "${CONFIG_TEMPLATE}" "${CONFIG_PATH}"
fi

if [[ "${CI_MOCK_ENGINE:-0}" == "1" ]]; then
  cat >"${APPIMAGE_PATH}" <<'PY'
#!/usr/bin/env python3
import json
import sys


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print("Usage: katago [--version|analysis]", file=sys.stderr)
        return 1
    if args[0] == "--version":
        print("KataGo v1.16.3-mock (CI)")
        return 0
    if args[0] == "analysis":
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                continue
            request_id = payload.get("id", "mock")
            response = {
                "id": request_id,
                "isAlive": False,
                "version": "v1.16.3-mock",
            }
            sys.stdout.write(json.dumps(response) + "\n")
            sys.stdout.flush()
        return 0
    print(f"Unsupported arguments: {args}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
PY
  chmod +x "${APPIMAGE_PATH}"
  echo "Using CI mock KataGo engine" >&2
  "${APPIMAGE_PATH}" --version
  exit 0
fi

install_appimage() {
  echo "Installing KataGo from ${ZIP_URL} into ${BIN_DIR}" >&2

  if [[ ! -f "${ZIP_PATH}" ]]; then
    tmp_zip="${ZIP_PATH}.tmp"
    echo "Downloading KataGo release zip..." >&2
    curl -fL "${ZIP_URL}" -o "${tmp_zip}"
    mv "${tmp_zip}" "${ZIP_PATH}"
  fi

  unzip -o "${ZIP_PATH}" -d "${BIN_DIR}" >/dev/null

  appimage_source="$(find "${BIN_DIR}" -maxdepth 1 -type f -name '*.AppImage' | head -n1)"
  if [[ -z "${appimage_source}" ]]; then
    echo "Failed to locate KataGo AppImage after unzip. Contents:" >&2
    ls -al "${BIN_DIR}" >&2
    exit 1
  fi

  mv -f "${appimage_source}" "${APPIMAGE_PATH}"
  chmod +x "${APPIMAGE_PATH}"
}

extract_appimage() {
  if [[ -L "${APPIMAGE_PATH}" ]]; then
    return
  fi
  pushd "${ROOT_DIR}" >/dev/null
  "${APPIMAGE_PATH}" --appimage-extract || true
  if [[ -f "squashfs-root/usr/bin/katago" ]]; then
    mv -f "squashfs-root/usr/bin/katago" "${EXTRACTED_BIN}"
    chmod +x "${EXTRACTED_BIN}"
    rm -rf "squashfs-root"
    ln -sfn "katago.bin" "${APPIMAGE_PATH}"
  fi
  popd >/dev/null
}

if [[ ! -e "${APPIMAGE_PATH}" ]]; then
  install_appimage
fi

if [[ ! -x "${APPIMAGE_PATH}" ]]; then
  install_appimage
fi

extract_appimage

if [[ ! -x "${APPIMAGE_PATH}" ]]; then
  echo "KataGo binary at ${APPIMAGE_PATH} is not executable after extraction." >&2
  exit 1
fi

if [[ -L "${APPIMAGE_PATH}" && ! -x "${EXTRACTED_BIN}" ]]; then
  echo "Extraction did not produce ${EXTRACTED_BIN}." >&2
  echo "Remove ${BIN_DIR} and rerun ./scripts/native_install.sh." >&2
  exit 1
fi

if ! "${APPIMAGE_PATH}" --version; then
  echo "KataGo binary at ${APPIMAGE_PATH} failed to run. Try re-running ./scripts/native_install.sh." >&2
  exit 1
fi
