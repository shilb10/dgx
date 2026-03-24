include $(HOME)/.env
export

REGISTRY ?= localhost:5000
TAG ?= latest

# Project-specific configurations
VLLM_IMAGE = vllm_modified
VLLM_DOCKERFILE = vllm/Dockerfile
VLLM_CONTEXT = .

OPENWEBUI_IMAGE = openwebui
OPENWEBUI_DOCKERFILE = openwebui/Dockerfile
OPENWEBUI_CONTEXT = .

SEARXNG_IMAGE = searxng
SEARXNG_DOCKERFILE = searxng/Dockerfile
SEARXNG_CONTEXT = searxng

COMFYUI_IMAGE = comfyui
COMFYUI_DOCKERFILE = comfyui/Dockerfile
COMFYUI_CONTEXT = .


.PHONY: build push build-vllm build-comfyui build-openwebui build-searxng build-bg push-vllm push-openwebui push-searxng

# Generic build template
define build-image
	docker build --progress=plain \
		-t $(REGISTRY)/$(1):$(TAG) \
		-f $(2) \
		$(3) \
		$(4)
endef

# Generic background build template
define build-bg-template
	@mkdir -p $(1)
	@echo "Starting background build of $(1), logging to $(1)/build.log..."
	@nohup $(MAKE) build-$(1) > $(1)/build.log 2>&1 & echo $$! > $(1)/build.pid
	@echo "Build running in background (PID: $$(cat $(1)/build.pid))"
	@echo "Monitor with: tail -f $(1)/build.log"
endef

# Specific image targets
build-vllm:
	$(call build-image,$(VLLM_IMAGE),$(VLLM_DOCKERFILE),$(BUILD_ARGS),$(VLLM_CONTEXT))

build-comfyui:
	$(call build-image,$(COMFYUI_IMAGE),$(COMFYUI_DOCKERFILE),$(BUILD_ARGS),$(COMFYUI_CONTEXT))

build-openwebui:
	$(call build-image,$(OPENWEBUI_IMAGE),$(OPENWEBUI_DOCKERFILE),$(BUILD_ARGS),$(OPENWEBUI_CONTEXT))

build-searxng:
	$(call build-image,$(SEARXNG_IMAGE),$(SEARXNG_DOCKERFILE),$(BUILD_ARGS),$(SEARXNG_CONTEXT))

build-vllm-bg:
	$(call build-bg-template,vllm)

build-openwebui-bg:
	$(call build-bg-template,openwebui)

build-searxng-bg:
	$(call build-bg-template,searxng)

# Default targets
build: build-vllm build-openwebui build-searxng

build-bg: build-vllm-bg build-openwebui-bg build-searxng-bg

push-vllm: build-vllm
	docker push $(REGISTRY)/$(VLLM_IMAGE):$(TAG)

push-openwebui: build-openwebui
	docker push $(REGISTRY)/$(OPENWEBUI_IMAGE):$(TAG)

push-searxng: build-searxng
	docker push $(REGISTRY)/$(SEARXNG_IMAGE):$(TAG)

push-comfyui: build-comfyui
	docker push $(REGISTRY)/$(COMFYUI_IMAGE):$(TAG)

push: push-vllm push-openwebui push-searxng

# Generic run template
# Args: 1: Image Name, 2: Container Name, 3: Run Options, 4: Command
define run-container
	docker run -d --restart always --name $(2) $(3) $(REGISTRY)/$(1):$(TAG) $(4)
endef

# Run configurations
VLLM_RUN_OPTS = -it --gpus all -p 8888:8000 \
	--ipc host --ulimit memlock=-1 --ulimit stack=67108864 \
	-v /var/lib/vllm_modified/model_cache:/root/.cache/huggingface \
	-v /var/lib/vllm_modified/vllm_cache:/root/.cache/vllm

# Emb run configs
VLLM_RUN_EMB_OPTS = -it --gpus all -p 8889:8000 \
	--ipc host --ulimit memlock=-1 --ulimit stack=67108864 \
	-v /var/lib/vllm_modified/model_cache:/root/.cache/huggingface \
	-v /var/lib/vllm_modified/vllm_cache:/root/.cache/vllm

# removed vllm serve command due to switch to using vllm:vllm-openai
VLLM_CMD = Qwen/Qwen3.5-35B-A3B-FP8 --reasoning-parser qwen3 --enable-auto-tool-choice --tool-call-parser qwen3_coder --gpu-memory-utilization .5
# VLLM_CMD = vllm serve Qwen/Qwen3-VL-30B-A3B-Instruct-FP8 --max-model-len 128000 --enable-auto-tool-choice --tool-call-parser hermes --gpu-memory-utilization .4
# VLLM_CMD = vllm serve Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8 --max-model-len 262144 --enable-auto-tool-choice --tool-call-parser qwen3_coder --gpu-memory-utilization .6
# VLLM_CMD = vllm serve ig1/Qwen3-Coder-30B-A3B-Instruct-NVFP4 --max-model-len 256000 --enable-auto-tool-choice --tool-call-parser qwen3_coder
VLLM_EMB_CMD = vllm serve Qwen/Qwen3-Embedding-4B --task embedding --gpu-memory-utilization .15 --max-model-len 32768

OPENWEBUI_RUN_OPTS = -it -p 3000:8080 -e OPENWEBUI_HOST=0.0.0.0 \
	-v /var/lib/openwebui:/app/backend/data

OPENWEBUI_CMD =

SEARXNG_RUN_OPTS = -p 8081:8080 \
	-v $(PWD)/searxng/settings.yaml:/etc/searxng/settings.yml:ro

SEARXNG_CMD =

run-vllm:
	@mkdir -p /var/lib/vllm_modified/model_cache /var/lib/vllm_modified/vllm_cache
	$(call run-container,$(VLLM_IMAGE),$(VLLM_IMAGE),$(VLLM_RUN_OPTS),$(VLLM_CMD))

run-vllm-emb:
	@mkdir -p /var/lib/vllm_modified/model_cache /var/lib/vllm_modified/vllm_cache
	$(call run-container,$(VLLM_IMAGE),vllm_modified_emb,$(VLLM_RUN_EMB_OPTS),$(VLLM_EMB_CMD))

run-openwebui:
	@mkdir -p /var/lib/openwebui
	$(call run-container,$(OPENWEBUI_IMAGE),$(OPENWEBUI_IMAGE),$(OPENWEBUI_RUN_OPTS),$(OPENWEBUI_CMD))

run-searxng:
	$(call run-container,$(SEARXNG_IMAGE),$(SEARXNG_IMAGE),$(SEARXNG_RUN_OPTS),$(SEARXNG_CMD))

run-registry:
	@mkdir -p /var/lib/registry
	docker run -d -p 5000:5000 -v /var/lib/registry:/var/lib/registry --restart=always --name local-registry registry:2

run: run-vllm run-openwebui run-searxng
