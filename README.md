- Ubuntu 24.04+
- NVIDIA driver + NVIDIA Container Toolkit
  - The Docker image uses `nvidia/cuda:12.3.2-runtime-ubuntu24.04`. CUDA 12.3 requires NVIDIA driver **525.60.13** or newer on Linux. The CUDA 12.3 GA release bundles driver **545.23.06**.
  - NVIDIA documents that the host driver must be **the same version or newer** than the driver inside the container image in order to run CUDA workloads successfully. See the [CUDA Compatibility guide](https://docs.nvidia.com/deploy/cuda-compatibility/index.html#cuda-compatibility-and-upgrades) for details on driver/container interoperability.
  - Verify your installed driver via `nvidia-smi`. If the driver is older than 525.60.13, upgrade it or rebuild the container with a CUDA base image that matches your driver.
- KaTrain installed on host (`pip install KaTrain`)
Refs: KataGo repo & releases, KataGo Analysis Engine docs, kata1 network files, NVIDIA Container Toolkit docs.
[v] https://github.com/lightvector/KataGo
[v] https://github.com/lightvector/KataGo/releases
[v] https://lightvector.github.io/KataGo/analysis.html
[v] https://katagotraining.org/networks/
[v] https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html

## Quickstart
```bash
cd go-ai
./scripts/00_setup_dirs.sh
./scripts/01_get_model.sh   # follow prompt; keep kata1*.bin.gz name
./scripts/02_build.sh       # builds local/katago:<KATAGO_VER> image via docker compose
./scripts/03_run.sh         # launches katago-analysis container with docker compose
./scripts/04_benchmark.sh   # queries the KataGo analysis engine and prints JSON
```

To change how many CPU threads KataGo uses for analysis, export `KATAGO_ANALYSIS_THREADS` before starting the container, for example:

```bash
export KATAGO_ANALYSIS_THREADS=16
./scripts/03_run.sh
```

## KaTrain configuration
KaTrain connects to KataGo through its JSON analysis engine over a socket. Configure the engine in KaTrain → Settings → Engine:

- Engine type: **KataGo JSON (socket)**
- Host: `127.0.0.1`
- Port: `${KATAGO_PORT}` (defaults to `2388` if unset)
- Model: point to the same `.bin.gz` network in your `models/` directory

Once the container is running, KaTrain can attach to the host port and stream KataGo analysis.
