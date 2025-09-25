# KaTrain + KataGo via Docker GPU

This guide shows how to run KataGo inside Docker with GPU acceleration and connect it to KaTrain on Ubuntu with an NVIDIA RTX 3090.

## Prerequisites

Ensure the following are installed and working on the host:

1. NVIDIA GPU drivers (`nvidia-smi` should succeed).
2. Docker Engine (the `docker` command must work for your user).
3. NVIDIA Container Toolkit (`nvidia-ctk runtime configure --runtime=docker` followed by `sudo systemctl restart docker`).

## Verify your environment

```bash
bash tools/check_env.sh
```

Expected result: the script prints versions of `nvidia-smi`, `docker`, (optionally) `nvidia-ctk`, then runs `nvidia/cuda:12.4.1-base-ubuntu22.04` with GPU access and shows the `nvidia-smi` table from inside the container.

- If you see `unknown flag: --gpus`, install and configure the NVIDIA Container Toolkit.
- If the container cannot access the GPU, verify driver installation and toolkit configuration.

## Prepare KataGo assets

1. Download a KataGo neural network (e.g. `kata1-b28c512nbt-s10904468224-d5317014586.bin.gz`) into `docker/models/`.
2. Optionally adjust `docker/example-analysis.cfg` for your preferences. The defaults favor stability on a 3090.
3. Keep `docker/example-gtp.cfg` as a reference for non-analysis use cases.

To discover likely paths for KaTrain, run:

```bash
python3 tools/detect_paths.py
```

The script prints a suggested executable path and arguments based on files it finds.

## Configure the Docker wrapper

1. Ensure the wrapper is executable:

   ```bash
   chmod +x tools/katago-docker.sh
   ```

2. (Optional) Pre-pull the KataGo image or override it:

   ```bash
   docker pull lightvector/katago:latest-cuda
   # or choose a different tag
   export KATAGO_IMAGE=lightvector/katago:v1.15.3-cuda
   ```

## Configure KaTrain

In KaTrain’s **Engine Settings** dialog:

- **Path to KataGo executable:** absolute path to `tools/katago-docker.sh`.
- **Arguments:**
  ```
  gtp -model /absolute/path/to/docker/models/<yourmodel>.bin.gz -config /absolute/path/to/docker/example-analysis.cfg
  ```
- Leave the engine type as CUDA (do not enable OpenCL or Eigen inside KaTrain).

When you click **Start Engine**, KaTrain will invoke the wrapper. The wrapper launches `docker run --gpus all` with read-only mounts for every absolute path passed to KataGo, so the container sees exactly the same paths KaTrain provides.

## Troubleshooting

- **KaTrain says “engine could not start”:** Copy the command from KaTrain’s log and run it in a terminal. Docker’s error message will show what went wrong.
- **`--gpus` is unknown:** Install the NVIDIA Container Toolkit and re-run `nvidia-ctk runtime configure --runtime=docker`, then restart Docker.
- **Container cannot read models or configs:** Ensure the arguments you pass to KaTrain are absolute paths that exist on the host. The wrapper mounts the parent directories read-only at their absolute locations.
- **Need a different KataGo image:** Set `KATAGO_IMAGE` before launching KaTrain or edit the environment variable in your shell profile.

