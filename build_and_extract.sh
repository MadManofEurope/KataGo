#!/usr/bin/env bash
set -euo pipefail

IMAGE="katago-build:fix"
CONTAINER="kb"

usage() {
    cat <<'EOF'
Usage: build_and_extract.sh [--cuda-architectures <value>]

Build the KataGo CUDA binary inside Docker and copy it to the current directory.

Options:
  --cuda-architectures <value>  Override the CUDA architectures passed to CMake.
                                Use a semicolon-separated list (e.g. "75;80;86;89"),
                                "native" to auto-select based on the build image, or
                                an empty string to let CMake detect at runtime.
  -h, --help                    Show this help message and exit.
EOF
}

cuda_architectures="${CUDA_ARCHITECTURES:-native}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cuda-architectures=*)
            cuda_architectures="${1#*=}"
            shift
            ;;
        --cuda-architectures)
            shift
            if [[ $# -eq 0 ]]; then
                echo "Error: --cuda-architectures requires a value." >&2
                exit 1
            fi
            cuda_architectures="$1"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

rm -f katago

docker build \
    -f Dockerfile.build \
    -t "${IMAGE}" \
    --build-arg CUDA_ARCHITECTURES="${cuda_architectures}" \
    .

docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
docker create --name "${CONTAINER}" "${IMAGE}"

docker cp "${CONTAINER}:/src/build/katago" ./katago

docker rm "${CONTAINER}"

./katago version --cuda-architectures
