# Local Go Coach: KataGo in Docker + KaTrain on host

## Requirements
- Ubuntu 24.04+
- NVIDIA driver + NVIDIA Container Toolkit
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
./scripts/01_get_model.sh   # follow prompt; save as models/latest.bin.gz
./scripts/02_build.sh
./scripts/03_run.sh
./scripts/04_benchmark.sh   # see JSON reply
