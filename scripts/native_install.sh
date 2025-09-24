#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${ROOT_DIR}/.bin"
MODELS_DIR="${ROOT_DIR}/models"
LOGS_DIR="${ROOT_DIR}/logs"
CONFIG_DIR="${ROOT_DIR}/config"
CONFIG_TEMPLATE="${CONFIG_DIR}/analysis.cfg.template"
CONFIG_PATH="${CONFIG_DIR}/analysis.cfg"
RELEASE_TAG="v1.16.3"
RELEASE_API_URL="https://api.github.com/repos/lightvector/KataGo/releases/tags/${RELEASE_TAG}"
ZIP_URL_OVERRIDE="${KATAGO_RELEASE_URL:-}"
APPIMAGE_URL="https://github.com/lightvector/KataGo/releases/download/${RELEASE_TAG}/katago-v1.16.3-cuda12.8-linux-x64.AppImage"
APPIMAGE_PATH="${BIN_DIR}/katago.AppImage"
KATAGO_BIN="${BIN_DIR}/katago"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd curl

mkdir -p "${BIN_DIR}" "${MODELS_DIR}" "${CONFIG_DIR}" "${LOGS_DIR}"

if [[ -f "${CONFIG_TEMPLATE}" && ! -f "${CONFIG_PATH}" ]]; then
  cp "${CONFIG_TEMPLATE}" "${CONFIG_PATH}"
fi

if [[ "${CI_MOCK_ENGINE:-0}" == "1" ]]; then
  cat >"${KATAGO_BIN}" <<'PY'
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
  chmod +x "${KATAGO_BIN}"
  echo "Using CI mock KataGo engine" >&2
  "${KATAGO_BIN}" --version
  exit 0
fi

determine_zip_url() {
  if [[ -n "${ZIP_URL_OVERRIDE}" ]]; then
    printf '%s' "${ZIP_URL_OVERRIDE}"
    return 0
  fi

  require_cmd jq

  # shellcheck disable=SC2016 # jq script uses regexes and literal $ characters.
  local jq_filter='
    [ .assets[]
      | .browser_download_url
      | select(test("linux-x64\\.zip$"))
      | select((test("trt") | not))
      | { url: ., score: (
          if test("eigen-linux-x64") then 500
          elif test("eigenavx2-linux-x64") then 450
          elif test("opencl") then 400
          elif test("cuda12\\.8") then 300
          elif test("cuda12\\.5") then 200
          elif test("cuda12\\.1") then 100
          else 0 end
        ) }
    ] as $assets
    | ($assets | map(select(.score > 0))) as $candidates
    | if ($candidates | length) == 0 then empty else ($candidates | max_by([.score, .url]) | .url) end
  '

  local -a curl_args=("-fsSL" "-H" "Accept: application/vnd.github+json")
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl_args+=("-H" "Authorization: Bearer ${GITHUB_TOKEN}")
    curl_args+=("-H" "X-GitHub-Api-Version: 2022-11-28")
  fi

  local response
  if ! response="$(curl "${curl_args[@]}" "${RELEASE_API_URL}")"; then
    echo "Failed to query GitHub release metadata from ${RELEASE_API_URL}" >&2
    echo "Set GITHUB_TOKEN to increase the API rate limit or override with KATAGO_RELEASE_URL." >&2
    exit 1
  fi

  local asset_url
  if ! asset_url="$(printf '%s' "${response}" | jq -r "${jq_filter}")"; then
    echo "Failed to parse GitHub release metadata." >&2
    exit 1
  fi

  if [[ -z "${asset_url}" || "${asset_url}" == "null" ]]; then
    echo "Could not find a Linux x64 KataGo ${RELEASE_TAG} asset from ${RELEASE_API_URL}." >&2
    echo "Specify KATAGO_RELEASE_URL to override the download target." >&2
    exit 1
  fi

  printf '%s' "${asset_url}"
}

install_appimage() {
  local arch
  arch="$(uname -m 2>/dev/null || echo unknown)"
  if [[ "${arch}" != "x86_64" && "${arch}" != "amd64" ]]; then
    echo "Host architecture ${arch} is not supported by the KataGo AppImage." >&2
    return 1
  fi

  if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "nvidia-smi not found; unable to confirm NVIDIA GPU presence. Skipping AppImage download." >&2
    return 1
  fi

  if ! nvidia-smi >/dev/null 2>&1; then
    echo "nvidia-smi command failed; skipping AppImage download." >&2
    return 1
  fi

  echo "Installing KataGo AppImage from ${APPIMAGE_URL}" >&2
  local tmp_path="${APPIMAGE_PATH}.tmp"
  rm -f "${tmp_path}" "${APPIMAGE_PATH}"
  if ! curl -fL "${APPIMAGE_URL}" -o "${tmp_path}"; then
    echo "Failed to download KataGo AppImage." >&2
    rm -f "${tmp_path}"
    return 1
  fi

  mv -f "${tmp_path}" "${APPIMAGE_PATH}"
  chmod +x "${APPIMAGE_PATH}"

  cat >"${KATAGO_BIN}" <<'WRAPPER'
#!/usr/bin/env bash
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/katago.AppImage" "$@"
WRAPPER
  chmod +x "${KATAGO_BIN}"

  INSTALL_METHOD="appimage"
  return 0
}

install_zip_release() {
  require_cmd unzip

  local zip_url
  zip_url="$(determine_zip_url)"
  local zip_basename="${zip_url##*/}"
  local zip_path="${BIN_DIR}/${zip_basename}"

  echo "Installing KataGo ZIP release from ${zip_url}" >&2

  if [[ ! -f "${zip_path}" ]]; then
    local tmp_zip="${zip_path}.tmp"
    echo "Downloading KataGo release zip..." >&2
    if ! curl -fL "${zip_url}" -o "${tmp_zip}"; then
      echo "Failed to download KataGo release zip." >&2
      rm -f "${tmp_zip}"
      exit 1
    fi
    mv "${tmp_zip}" "${zip_path}"
  fi

  local unzip_dir
  unzip_dir="$(mktemp -d)"
  unzip -qo "${zip_path}" -d "${unzip_dir}"

  local binary_source
  binary_source="$(find "${unzip_dir}" -type f -name 'katago' | head -n1)"
  if [[ -z "${binary_source}" ]]; then
    echo "Failed to locate KataGo binary inside ${zip_basename}. Contents:" >&2
    find "${unzip_dir}" -maxdepth 2 -type f -print >&2 || true
    rm -rf "${unzip_dir}"
    exit 1
  fi

  local tmp_path="${KATAGO_BIN}.tmp"
  rm -f "${tmp_path}" "${KATAGO_BIN}"
  cp "${binary_source}" "${tmp_path}"
  chmod +x "${tmp_path}"
  mv -f "${tmp_path}" "${KATAGO_BIN}"

  rm -rf "${unzip_dir}"
  rm -f "${APPIMAGE_PATH}"

  INSTALL_METHOD="zip"
}

check_libzip_dependency() {
  if [[ "${INSTALL_METHOD}" != "zip" ]]; then
    return 0
  fi

  if ! command -v ldd >/dev/null 2>&1; then
    return 0
  fi

  if ldd "${KATAGO_BIN}" 2>/dev/null | grep -q 'libzip.so.4 => not found'; then
    echo "The KataGo ZIP binary is missing libzip.so.4 on this system." >&2
    echo "Using AppImage avoids libzip issues. Run ./scripts/native_install.sh again." >&2
    exit 1
  fi
}

verify_analysis_subcommand() {
  set +e
  local output
  output="$("${KATAGO_BIN}" analysis -help 2>&1)"
  local status=$?
  set -e
  if [[ ${status} -ne 0 ]]; then
    if [[ "${output}" == *"libzip.so.4"* ]]; then
      echo "Using AppImage avoids libzip issues. Run ./scripts/native_install.sh again." >&2
    fi
    echo "KataGo binary at ${KATAGO_BIN} could not run the analysis subcommand." >&2
    echo "Remove ${BIN_DIR} and rerun ./scripts/native_install.sh." >&2
    exit 1
  fi
}

verify_version_command() {
  if ! "${KATAGO_BIN}" version >/dev/null 2>&1; then
    if ! "${KATAGO_BIN}" --version >/dev/null 2>&1; then
      echo "KataGo binary at ${KATAGO_BIN} failed to report its version." >&2
      echo "Try re-running ./scripts/native_install.sh or override KATAGO_RELEASE_URL." >&2
      exit 1
    fi
  fi
}

INSTALL_METHOD=""

if [[ -L "${KATAGO_BIN}" ]]; then
  rm -f "${KATAGO_BIN}"
fi

if install_appimage; then
  :
else
  echo "Falling back to the KataGo ZIP release." >&2
  install_zip_release
fi

if [[ ! -x "${KATAGO_BIN}" ]]; then
  echo "KataGo binary at ${KATAGO_BIN} is not executable after installation." >&2
  exit 1
fi

check_libzip_dependency
verify_analysis_subcommand
verify_version_command
