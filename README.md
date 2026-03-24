# vllm_modified — Makefile usage

This repository provides Make targets to build and run local Docker images and a local Docker registry.

Key variables (can be overridden on `make` command line):

- `REGISTRY` — image registry host (default: `localhost:5000`)
- `TAG` — image tag (default: `latest`)

Examples:

- Build all images: `make build`
- Run local registry (creates `REGISTRY_DATA` if needed):
  `make run-registry`
- Push vllm image to registry: `make push-vllm REGISTRY=localhost:5000 TAG=latest`

See `Makefile` for other targets and options.

**OpenWebUI**

- Build: `make build-openwebui` (uses `openwebui/Dockerfile`).
- Run: `make run-openwebui` — this starts the container with port `3000` on the host mapped to `8080` in the container and mounts `/var/lib/openwebui` to `/app/backend/data` inside the container.
- If you need to run manually:

```bash
docker build -t openwebui:$(TAG) -f openwebui/Dockerfile openwebui
docker run -it -p 3000:8080 -e OPENWEBUI_HOST=0.0.0.0 -v /var/lib/openwebui:/app/backend/data openwebui:$(TAG)
```

**vllm**

- Build: `make build-vllm` (uses `vllm/Dockerfile`).
- Run: `make run-vllm` — this target ensures the host cache dirs `/var/lib/vllm_modified/model_cache` and `/var/lib/vllm_modified/vllm_cache` exist, then starts the container with `8888:8000` mapped and GPU options enabled as configured in the `Makefile`.
- Embeddings: `make run-vllm-emb` runs the embedding server on a separate port (`8889`).
- Manual run example:

```bash
mkdir -p /var/lib/vllm_modified/model_cache /var/lib/vllm_modified/vllm_cache
docker build -t vllm_modified:$(TAG) -f vllm/Dockerfile .
docker run -it --gpus all -p 8888:8000 --ipc host --ulimit memlock=-1 --ulimit stack=67108864 \
  -v /var/lib/vllm_modified/model_cache:/root/.cache/huggingface \
  -v /var/lib/vllm_modified/vllm_cache:/root/.cache/vllm vllm_modified:$(TAG) <serve-cmd-or-entrypoint-args>
```

**Registry & pushing images**

- `make run-registry` creates and uses `/var/lib/registry` (host) for the local registry storage and runs `registry:2` on `localhost:5000`.
- Push an image: `make push-vllm` (or `make push-vllm REGISTRY=yourhost:port TAG=yourtag`).

