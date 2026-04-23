################################################################################
#         ____  ___________               __          __                       #
#        / __ \/ __/ __/ (_)___  ___     / /   ____ _/ /_                      #
#       / / / / /_/ /_/ / / __ \/ _ \   / /   / __ `/ __ \                     #
#      / /_/ / __/ __/ / / / / /  __/  / /___/ /_/ / /_/ /                     #
#      \____/_/ /_/ /_/_/_/ /_/\___/  /_____/\__,_/_.___/                      #
#                                                                              #
#      Copyright (C) 2025-2026 Offline Lab                                     #
#      Contact: info@offline-lab.com                                           #
#                                                                              #
#      SPDX-License-Identifier: GPL-2.0-only                                   #
#                                                                              #
################################################################################

SHELL        := $(shell which bash )
IMAGE_NAME   := debos-builder
OUTPUT_IMAGE := offline-lab-pi.img.gz
OUTPUT_DIR   := $(CURDIR)/build

DOCKER_FLAGS := \
	--rm \
	--tty \
	--interactive \
	--privileged \
	--platform linux/arm64 \
	-v $(CURDIR)/recipes:/work/recipes:ro \
	-v $(CURDIR)/overlays:/work/overlays:ro \
	-v $(CURDIR)/offline-lab.yaml:/work/offline-lab.yaml:ro \
	-v $(OUTPUT_DIR)/artifacts:/artifacts \
	-e APT_PROXY=$(APT_PROXY) \
	-e http_proxy=$(if $(APT_PROXY),$(APT_PROXY),) \
	-e https_proxy=$(if $(APT_PROXY),$(APT_PROXY),)

DEBOS_FLAGS := \
	--verbose \
	--debug-shell \
	--shell=/bin/bash \
	--cpus=8 \
	--memory=8192MB \
	--artifactdir=/artifacts

BUILD_ARGS ?=

.PHONY: all container image shell clean

all: image

artifacts:
	mkdir -p $(OUTPUT_DIR)/artifacts

container: artifacts
	docker build $(BUILD_ARGS) --build-arg APT_PROXY=$(APT_PROXY) -t $(IMAGE_NAME) .

image: container
	docker run $(DOCKER_FLAGS) $(IMAGE_NAME) debos $(DEBOS_FLAGS) /work/offline-lab.yaml
	cp $(OUTPUT_DIR)/artifacts/$(OUTPUT_IMAGE) $(OUTPUT_DIR)/$(OUTPUT_IMAGE)

shell: container
	docker run $(DOCKER_FLAGS) $(IMAGE_NAME) /bin/bash

clean:
	rm -f $(OUTPUT_DIR)/*.img $(OUTPUT_DIR)/*.squashfs
	rm -rf $(OUTPUT_DIR)/artifacts
