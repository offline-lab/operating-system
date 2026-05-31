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
# offlinelab-disco
#
# Service discovery, NSS, and time sync for offline networks.
# Source fetched from GitHub at build time — nothing stored in br2-builder.
#
################################################################################

OFFLINELAB_DISCO_VERSION = $(call qstrip,$(BR2_PACKAGE_OFFLINELAB_DISCO_VERSION))
OFFLINELAB_DISCO_SITE = $(call github,offline-lab,disco,$(OFFLINELAB_DISCO_VERSION))
OFFLINELAB_DISCO_LICENSE = MIT
OFFLINELAB_DISCO_LICENSE_FILES = LICENSE

OFFLINELAB_DISCO_DEPENDENCIES = host-go systemd
OFFLINELAB_DISCO_SRC_DIR = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-disco/src

OFFLINELAB_DISCO_GO_ENV = \
	PATH="$(HOST_DIR)/bin:$(PATH)" \
	GOPATH="$(@D)/.gopath" \
	GOPROXY=https://proxy.golang.org,direct \
	GOFLAGS=-modcacherw \
	GOOS=linux \
	GOARCH=$(if $(BR2_aarch64),arm64,$(if $(BR2_arm),arm,$(GO_GOARCH))) \
	CGO_ENABLED=0

OFFLINELAB_DISCO_LDFLAGS = -s -w \
	-X main.Version=$(OFFLINELAB_DISCO_VERSION) \
	-X main.BuildTime=$(shell date -u '+%Y-%m-%d_%H:%M:%S')

OFFLINELAB_DISCO_BUILD_TARGETS = disco-daemon disco disco-gps-broadcaster

define OFFLINELAB_DISCO_BUILD_CMDS
	$(foreach t,$(OFFLINELAB_DISCO_BUILD_TARGETS), \
		cd $(@D) && $(OFFLINELAB_DISCO_GO_ENV) $(HOST_DIR)/bin/go build \
			-ldflags="$(OFFLINELAB_DISCO_LDFLAGS)" \
			-trimpath -buildvcs=false \
			-o $(@D)/bin/$(t) ./cmd/$(if $(filter disco-daemon,$(t)),daemon,$(if $(filter disco-gps-broadcaster,$(t)),gps-broadcaster,$(t)))/main.go
	)
	$(TARGET_CC) $(TARGET_CFLAGS) -fPIC -shared \
		-o $(@D)/bin/libnss_disco.so.2 \
		-Wl,-soname,libnss_disco.so.2 \
		-D_GNU_SOURCE \
		$(@D)/libnss/nss_disco.c
endef

define OFFLINELAB_DISCO_INSTALL_TARGET_CMDS
	$(foreach t,$(OFFLINELAB_DISCO_BUILD_TARGETS), \
		$(INSTALL) -D -m 0755 $(@D)/bin/$(t) $(TARGET_DIR)/usr/bin/$(t)
	)

	$(INSTALL) -D -m 0755 $(@D)/bin/libnss_disco.so.2 \
		$(TARGET_DIR)/usr/lib/libnss_disco.so.2

	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants
	mkdir -p $(TARGET_DIR)/data/config/disco

	$(INSTALL) -D -m 0644 $(OFFLINELAB_DISCO_SRC_DIR)/systemd/service/disco-daemon.service \
		$(TARGET_DIR)/etc/systemd/system/disco-daemon.service
	ln -sf /etc/systemd/system/disco-daemon.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/disco-daemon.service

	$(INSTALL) -D -m 0644 $(OFFLINELAB_DISCO_SRC_DIR)/systemd/service/provision-disco.service \
		$(TARGET_DIR)/etc/systemd/system/provision-disco.service
	ln -sf /etc/systemd/system/provision-disco.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/provision-disco.service

	$(INSTALL) -D -m 0755 $(OFFLINELAB_DISCO_SRC_DIR)/init-provision-disco \
		$(TARGET_DIR)/usr/local/bin/init-provision-disco

	$(INSTALL) -D -m 0644 $(OFFLINELAB_DISCO_SRC_DIR)/config/config.yaml \
		$(TARGET_DIR)/etc/disco/config.yaml

	$(INSTALL) -D -m 0644 $(OFFLINELAB_DISCO_SRC_DIR)/systemd/service/disco-gps-broadcaster.service \
		$(TARGET_DIR)/etc/systemd/system/disco-gps-broadcaster.service

	$(INSTALL) -D -m 0644 $(OFFLINELAB_DISCO_SRC_DIR)/systemd/preset/80-offlinelab-disco.preset \
		$(TARGET_DIR)/usr/lib/systemd/system-preset/80-offlinelab-disco.preset
endef

$(eval $(generic-package))
