# Local Go Coach: KataGo in Docker + KaTrain on host

## Requirements
- Ubuntu 24.04+  
- NVIDIA driver + NVIDIA Container Toolkit  
  - The Docker image uses `nvidia/cuda:12.3.2-runtime-ubuntu24.04`. For CUDA 12.3, the minimum required NVIDIA driver version on Linux is **525.60.13**.  
    The CUDA 12.3 GA release also bundles driver version **545.23.06**. Verify your installed driver via `nvidia-smi`.  
  - If your driver is older than 525.60.13, upgrade it, or rebuild the container using a CUDA base image compatible with your driver.  
- KaTrain installed on host (`pip install KaTrain`)

Refs: KataGo repo & releases, kata1 network files, NVIDIA Container Toolkit docs.  
[v] https://github.com/lightvector/KataGo  
[v] https://github.com/lightvector/KataGo/releases  
[v] https://katagotraining.org/networks/  
[v] https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html

## Quickstart
```bash
cd go-ai
./scripts/00_setup_dirs.sh
./scripts/01_get_model.sh   # follow prompt; keep kata1*.bin.gz name
./scripts/02_build.sh
./scripts/03_run.sh
./scripts/04_probe.sh       # verify JSON analysis fields
```

To change how many CPU threads KataGo uses for analysis, export `KATAGO_ANALYSIS_THREADS` before starting the container, for example:

```bash
export KATAGO_ANALYSIS_THREADS=16
./scripts/03_run.sh
```
