#!/usr/bin/env bash
# Fetch a current kata1 "Network File" and verify it before use.
set -euo pipefail

cd "$(dirname "$0")/.."

MODELS_DIR="models"
mkdir -p "${MODELS_DIR}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to scrape kata1 network links. Install python3 and retry." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to download kata1 networks. Install curl and retry." >&2
  exit 1
fi

LISTING_URL="${1:-https://katagotraining.org/networks/kata1/}"

download_latest_network() {
  local listing_url="$1"
  local dest_dir="$2"

  local model_url
  if ! model_url="$(python3 - "$listing_url" <<'PY'
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
    raise SystemExit("No kata1 network links found at {}".format(listing_url))

print(parser.links[0])
PY
)"; then
    echo "Failed to determine latest kata1 network from ${listing_url}" >&2
    return 1
  fi

  local filename="${model_url##*/}"
  local tmp_file="${dest_dir}/${filename}.tmp"
  echo "Downloading ${filename} from ${model_url}" >&2
  if ! curl -fL "${model_url}" -o "${tmp_file}"; then
    echo "Download failed" >&2
    rm -f "${tmp_file}"
    return 1
  fi

  mv "${tmp_file}" "${dest_dir}/${filename}"
}

shopt -s nullglob
networks=("${MODELS_DIR}"/kata1*.bin.gz)
shopt -u nullglob

if [ "${#networks[@]}" -eq 0 ]; then
  echo "No kata1 network detected in ${MODELS_DIR}/. Attempting automatic download..." >&2
  if download_latest_network "${LISTING_URL}" "${MODELS_DIR}"; then
    shopt -s nullglob
    networks=("${MODELS_DIR}"/kata1*.bin.gz)
    shopt -u nullglob
  else
    echo "Automatic download failed. Manually download a kata1 network from ${LISTING_URL}" >&2
    exit 1
  fi
fi

if [ "${#networks[@]}" -gt 1 ]; then
  echo "Multiple kata1 network files detected:" >&2
  printf '  %s\n' "${networks[@]}" >&2
  echo "Keep only one kata1 network in ${MODELS_DIR}/ and re-run this script." >&2
  exit 1
fi

network_path="${networks[0]}"

# Verify gzip integrity without extracting
if ! gzip -t "${network_path}"; then
  echo "Network file ${network_path} failed gzip integrity check." >&2
  echo "Re-download the file; incomplete downloads are not usable." >&2
  exit 1
fi

ln -sf "$(basename "${network_path}")" "${MODELS_DIR}/latest.bin.gz"
echo "Verified $(basename "${network_path}") and linked it as ${MODELS_DIR}/latest.bin.gz"
