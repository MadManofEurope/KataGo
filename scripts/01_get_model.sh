#!/usr/bin/env bash
# Fetch the latest kata1 network and link it as models/latest.bin.gz.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODELS_DIR="${ROOT_DIR}/models"

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

if [ -f "${dest_path}" ]; then
  echo "${filename} already exists. Verifying integrity..."
else
  tmp_file="${dest_path}.tmp"
  echo "Downloading ${filename} from ${model_url}" >&2
  curl -fL "${model_url}" -o "${tmp_file}"
  mv "${tmp_file}" "${dest_path}"
fi

# Verify gzip integrity without extracting
if ! gzip -t "${dest_path}"; then
  echo "Network file ${dest_path} failed gzip integrity check." >&2
  echo "Re-download the file; incomplete downloads are not usable." >&2
  rm -f "${dest_path}"
  exit 1
fi

ln -sf "${filename}" "${MODELS_DIR}/latest.bin.gz"
echo "Linked ${filename} as models/latest.bin.gz"
