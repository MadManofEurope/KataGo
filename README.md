# Local Go Coach: KataGo in Docker + KaTrain on host

## Requirements
- Ubuntu 24.04+
- NVIDIA driver + NVIDIA Container Toolkit
- The Docker image uses `nvidia/cuda:12.5.1-runtime-ubuntu24.04`. For CUDA 12.5, the minimum required NVIDIA driver version on Linux is **555.42.02** (per the CUDA 12.5 GA release notes).
    The CUDA 12.5 GA release also bundles driver version **555.42.02**. Verify your installed driver via `nvidia-smi`.
  - If your driver is older than 555.42.02, upgrade it, or rebuild the container using a CUDA base image compatible with your driver.





[v] https://github.com/lightvector/KataGo  
[v] https://github.com/lightvector/KataGo/releases  
[v] https://katagotraining.org/networks/  
[v] https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html

## Quickstart
```bash
cd Katago
./scripts/00_setup_dirs.sh
./scripts/01_get_model.sh   # follow prompt; save as models/latest.bin.gz
./scripts/02_build.sh
./scripts/03_run.sh
./scripts/04_benchmark.sh   # see JSON reply
```

To change how many CPU threads KataGo uses for analysis, export `KATAGO_ANALYSIS_THREADS` before starting the container, for example:

```bash
export KATAGO_ANALYSIS_THREADS=16
./scripts/03_run.sh
```
