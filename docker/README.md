# KataGo Docker Image

The provided scripts assume the CUDA-enabled KataGo image published by Lightvector.

- **Default image:** `lightvector/katago:latest-cuda`
- Pull or update the image: `docker pull lightvector/katago:latest-cuda`
- Override the image by exporting `KATAGO_IMAGE` before launching KaTrain or the wrapper:
  - `export KATAGO_IMAGE=lightvector/katago:v1.15.3-cuda`

Any compatible KataGo build that includes the `katago` binary can be used. The wrapper will pass through the version specified via `KATAGO_IMAGE` when it starts containers.
