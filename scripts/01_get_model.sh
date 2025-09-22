#!/usr/bin/env bash
# Fetch a current kata1 "Network File" and save as models/latest.bin.gz
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p models
URL="${1:-https://katagotraining.org/networks/kata1/}"; echo "Manual step:"
echo "Open ${URL} and download the latest 'Network File' .bin.gz into models/ as latest.bin.gz"
echo "Reason: site uses dynamic listing; stable direct link not guaranteed."
