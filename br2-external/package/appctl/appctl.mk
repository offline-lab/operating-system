################################################################################
#         ____  ___________               __          __                       #
#        / __ \/ __/ __/ (_)___  ___     / /   ____ _/ /_                      #
#       / / / / /_/ /_/ / / __ \/ _ \   / /   / __ `/ __ \                     #
#      / /_/ / __/ __/ / / / / /  __/  / /___/ /_/ / /_/ /                     #
#      \____/_/ /_/ /_/_/_/ /_/\___/  /_____/\__,_/_.___/                      #
#                                                                              #
#      Copyright (C) 2025-2026 Offline Lab                                     #
#      Contact: info@offline-lab.com                                           #
#      SPDX-License-Identifier: AGPL-3.0-only                                  #
################################################################################

################################################################################
#
# appctl
#
# On-device package manager for Offline Lab OS.
# Source fetched from GitHub at build time — nothing stored in br2-builder.
#
################################################################################

APPCTL_VERSION = $(call qstrip,$(BR2_PACKAGE_APPCTL_VERSION))
APPCTL_SITE = $(call github,offline-lab,appctl,$(APPCTL_VERSION))
APPCTL_LICENSE = AGPL-3.0-only
APPCTL_LICENSE_FILES = LICENSE

APPCTL_DEPENDENCIES = host-go systemd

APPCTL_GO_ENV = \
	PATH="$(HOST_DIR)/bin:$(PATH)" \
	GOPATH="$(@D)/.gopath" \
	GOPROXY=https://proxy.golang.org,direct \
	GOFLAGS=-modcacherw \
	GOOS=linux \
	GOARCH=$(if $(BR2_aarch64),arm64,$(if $(BR2_arm),arm,$(GO_GOARCH))) \
	CGO_ENABLED=0

APPCTL_LDFLAGS = -s -w \
	-X main.Version=$(APPCTL_VERSION) \
	-X main.BuildTime=$(shell date -u '+%Y-%m-%d_%H:%M:%S')

define APPCTL_BUILD_CMDS
	cd $(@D) && $(APPCTL_GO_ENV) $(HOST_DIR)/bin/go build \
		-ldflags="$(APPCTL_LDFLAGS)" \
		-trimpath -buildvcs=false \
		-o $(@D)/bin/appctl ./cmd/appctl/main.go
endef

define APPCTL_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/bin/appctl $(TARGET_DIR)/usr/bin/appctl

	mkdir -p $(TARGET_DIR)/data/offline-lab/images
	mkdir -p $(TARGET_DIR)/data/config/keys
	mkdir -p $(TARGET_DIR)/data/config/sysusers.d
endef

$(eval $(generic-package))
