## Prerequisites

- Install an NVIDIA driver and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) on the host. Drivers must be compatible with the container’s CUDA version; see the [CUDA Compatibility guide](https://docs.nvidia.com/deploy/cuda-compatibility/index.html) for driver/container interoperability details.
- Configure Docker Compose for GPU access by following [Docker’s GPU in Compose documentation](https://docs.docker.com/compose/gpu-support/).
- The runtime image uses `nvidia/cuda:12.5.1-runtime-ubuntu24.04`. Verify your installed driver with `nvidia-smi`. If the driver is older than what the compatibility guide allows, upgrade it or rebuild the container with a CUDA base image that matches your driver.
- KaTrain installed on host (`pip install KaTrain`).

## Quickstart

```bash
cd KataGo
./scripts/00_setup_dirs.sh
./scripts/01_get_model.sh   # follow prompt; keep kata1*.bin.gz name
cp docker/analysis.cfg config/analysis.cfg  # customize as needed
export IMAGE_TAG=$(git rev-parse --short HEAD)
docker compose build --no-cache
docker compose up -d
docker compose logs -f katago
./scripts/04_benchmark.sh   # queries the KataGo analysis engine and prints JSON
```

To override how many CPU threads KataGo uses for analysis, export `KATAGO_ANALYSIS_THREADS` before starting the container. For
example, setting `export KATAGO_ANALYSIS_THREADS=16` and then running `docker compose up -d` asks the entrypoint to pass
`numAnalysisThreads=16` to KataGo. If you leave `KATAGO_ANALYSIS_THREADS` unset (or explicitly set it to an empty string), the
entrypoint omits the override and KataGo honors the value already defined in `config/analysis.cfg`.

You can also override `analysis.cfg` values without editing the file by exporting `KATAGO_VISITS` (maps to `maxVisits`) or
`KATAGO_SEARCH_THREADS` (maps to `numSearchThreadsPerAnalysisThread`). When these environment variables are set to positive integers,
the entrypoint passes them to `katago analysis` via `-override-config`, taking precedence over the base configuration. Leave them
unset (or empty) to keep the values defined in `analysis.cfg`.

### Building for specific CUDA architectures

The helper script `build_and_extract.sh` compiles the KataGo CUDA binary inside Docker. By default it requests `native` architectures,
which lets CMake choose an appropriate target for the build container's GPU stack. To explicitly compile kernels for multiple GPU
generations, set the semicolon-delimited list of architectures (for example `"75;80;86;89"`) via either the `CUDA_ARCHITECTURES`
environment variable or the script flag:

```bash
# Environment variable
CUDA_ARCHITECTURES="75;80;86;89" ./build_and_extract.sh

# Command-line flag
./build_and_extract.sh --cuda-architectures "75;80;86;89"
```

Passing an empty string (for example, `CUDA_ARCHITECTURES= ./build_and_extract.sh`) omits the CMake flag so KataGo detects supported
architectures at runtime instead of during compilation.

## KaTrain configuration

KaTrain connects to KataGo through its JSON analysis engine over a socket. Configure the engine in KaTrain → Settings → Engine:

- Engine type: **KataGo JSON (socket)**
- Host: `127.0.0.1`
- Port: `${KATAGO_PORT}` (defaults to `2388` if unset)
- Model: point to the same `.bin.gz` network in your `models/` directory

Once the container is running, KaTrain can attach to the host port and stream KataGo analysis.

The container entrypoint starts the KataGo analysis engine with `katago analysis -config <file> -model <file>`. The default
Compose file binds `./config/analysis.cfg` into the container and points `KATAGO_CONFIG` at `/config/analysis.cfg`, so any
changes to `config/analysis.cfg` are picked up on restart. KataGo's repository includes a fuller sample configuration at
[`cpp/configs/analysis_example.cfg`](https://github.com/lightvector/KataGo/blob/master/cpp/configs/analysis_example.cfg)
that can serve as a template when you need to reference additional options.

## References

- [KataGo repository](https://github.com/lightvector/KataGo)
- [KataGo releases](https://github.com/lightvector/KataGo/releases)
- [KataGo analysis engine docs](https://lightvector.github.io/KataGo/analysis.html)
- [KataGo network files](https://katagotraining.org/networks/)
- [NVIDIA Container Toolkit install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- [Docker: Use GPUs with Compose](https://docs.docker.com/compose/gpu-support/)
- [CUDA compatibility guide](https://docs.nvidia.com/deploy/cuda-compatibility/index.html)
