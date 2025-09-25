#!/usr/bin/env bash
# Fetch the latest kata1 network and link it as models/latest.bin.gz.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODELS_DIR="${ROOT_DIR}/models"

mkdir -p "${MODELS_DIR}"

MODEL_FILE="${MODEL_FILE:-}"

LISTING_URL="https://katagotraining.org/networks/kata1/"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      shift
      MODEL_FILE="${1:-}"
      if [[ -z "${MODEL_FILE}" ]]; then
        echo "ERROR: --file requires a path argument." >&2
        exit 1
      fi
      ;;
    --help)
      cat <<'USAGE'
Usage: ./scripts/01_get_model.sh [--file /path/to/kata1-network.bin.gz] [listing_url]

When --file or MODEL_FILE is provided, models/latest.bin.gz links to the given file.
Otherwise the latest kata1 network is downloaded from katagotraining.org (or a custom listing URL).
USAGE
      exit 0
      ;;
    *)
      LISTING_URL="$1"
      ;;
  esac
  shift || true
done

link_latest() {
  local source_path="$1"
  local abs_source
  abs_source="$(readlink -f "$source_path")"
  if [[ -z "${abs_source}" ]]; then
    echo "ERROR: Unable to resolve absolute path for $source_path" >&2
    exit 1
  fi
  if [[ "${abs_source}" != "${MODELS_DIR}/"* ]]; then
    echo "ERROR: ${abs_source} must live under ${MODELS_DIR}" >&2
    exit 1
  fi
  local base_name
  base_name="$(basename "${abs_source}")"
  ln -sfn "${base_name}" "${MODELS_DIR}/latest.bin.gz"
  echo "models/latest.bin.gz -> ${base_name}"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${MODELS_DIR}/${base_name}"
  fi
}

if [[ -n "${MODEL_FILE}" ]]; then
  if [[ ! -f "${MODEL_FILE}" ]]; then
    echo "ERROR: MODEL_FILE not found: ${MODEL_FILE}" >&2
    exit 1
  fi
  if [[ ! "${MODEL_FILE}" =~ \.bin\.gz$ ]]; then
    echo "ERROR: MODEL_FILE must end with .bin.gz" >&2
    exit 1
  fi
  base_name="$(basename "${MODEL_FILE}")"
  dest_path="${MODELS_DIR}/${base_name}"
  model_abs="$(readlink -f "${MODEL_FILE}")"
  dest_abs="$(readlink -f "${dest_path}" 2>/dev/null || true)"
  if [[ "${model_abs}" != "${dest_abs}" ]]; then
    echo "Copying ${MODEL_FILE} to ${dest_path}" >&2
    cp -f "${MODEL_FILE}" "${dest_path}"
  fi
  if ! gzip -t "${dest_path}"; then
    echo "Network file ${dest_path} failed gzip integrity check." >&2
    rm -f "${dest_path}"
    exit 1
  fi
  link_latest "${dest_path}"
else
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to scrape kata1 network links. Install python3 and retry." >&2
    exit 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to download kata1 networks. Install curl and retry." >&2
    exit 1
  fi

  model_url="$(python3 - "$LISTING_URL" <<'PY'
import sys
from html.parser import HTMLParser
from urllib.parse import urljoin
from urllib.request import urlopen

listing_url = sys.argv[1]


class Kata1LinkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag != "a":
            return
        href = dict(attrs).get("href")
        if not href:
            return
        if href.endswith(".bin.gz") and "kata1" in href:
            self.links.append(urljoin(listing_url, href))


with urlopen(listing_url) as resp:
    content = resp.read().decode("utf-8", "ignore")

parser = Kata1LinkParser()
parser.feed(content)

if not parser.links:
    raise SystemExit(f"No kata1 network links found at {listing_url}")

print(parser.links[0])
PY
)"

  filename="${model_url##*/}"
  dest_path="${MODELS_DIR}/${filename}"

  tmp_file="${dest_path}.tmp"

  if [ -f "${dest_path}" ]; then
    echo "${filename} already exists. Verifying integrity..."
  else
    echo "Downloading ${filename} from ${model_url}" >&2
    curl -fL "${model_url}" -o "${tmp_file}"
    mv "${tmp_file}" "${dest_path}"
  fi

  if ! gzip -t "${dest_path}"; then
    echo "Network file ${dest_path} failed gzip integrity check." >&2
    echo "Re-download the file; incomplete downloads are not usable." >&2
    rm -f "${dest_path}" "${tmp_file}"
    exit 1
  fi

  link_latest "${dest_path}"
fi

resolved="$(readlink -f "${MODELS_DIR}/latest.bin.gz" 2>/dev/null || true)"
if [[ -z "${resolved}" ]]; then
  echo "ERROR: models/latest.bin.gz could not be resolved." >&2
  exit 1
fi

echo "models/latest.bin.gz now points to ${resolved}"
