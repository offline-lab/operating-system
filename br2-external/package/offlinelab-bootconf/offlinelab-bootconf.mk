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
# offlinelab-bootconf
#
# Boot-time configuration tool. Reads /boot/firmware/bootconf.yaml and
# configures the system before other services start.
# Source fetched from GitHub at build time — nothing stored in br2-builder.
#
################################################################################

OFFLINELAB_BOOTCONF_VERSION = $(call qstrip,$(BR2_PACKAGE_OFFLINELAB_BOOTCONF_VERSION))
OFFLINELAB_BOOTCONF_SITE    = $(call github,offline-lab,bootconf,$(OFFLINELAB_BOOTCONF_VERSION))
OFFLINELAB_BOOTCONF_LICENSE       = AGPL-3.0-only
OFFLINELAB_BOOTCONF_LICENSE_FILES = LICENSE

OFFLINELAB_BOOTCONF_DEPENDENCIES = host-go systemd
OFFLINELAB_BOOTCONF_SRC_DIR = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-bootconf/src

OFFLINELAB_BOOTCONF_GO_ENV = \
	PATH="$(HOST_DIR)/bin:$(PATH)" \
	GOPATH="$(@D)/.gopath" \
	GOPROXY=https://proxy.golang.org,direct \
	GOFLAGS=-modcacherw \
	GOOS=linux \
	GOARCH=$(if $(BR2_aarch64),arm64,$(if $(BR2_arm),arm,$(GO_GOARCH))) \
	CGO_ENABLED=0

OFFLINELAB_BOOTCONF_PKG = github.com/offline-lab/bootconf/cmd/bootconf/commands

OFFLINELAB_BOOTCONF_LDFLAGS = -s -w \
	-X $(OFFLINELAB_BOOTCONF_PKG).Version=$(OFFLINELAB_BOOTCONF_VERSION)

# BuildTime and Commit are injected inside the recipe (not in the variable
# above) so that $$(date ...) is evaluated by the shell at build time, not by
# Make at parse time. Using $(shell ...) in .mk variables is disallowed by
# Buildroot style and would also break reproducible builds if SOURCE_DATE_EPOCH
# is in use.
define OFFLINELAB_BOOTCONF_BUILD_CMDS
	cd $(@D) && $(OFFLINELAB_BOOTCONF_GO_ENV) $(HOST_DIR)/bin/go build \
		-ldflags="$(OFFLINELAB_BOOTCONF_LDFLAGS) \
			-X $(OFFLINELAB_BOOTCONF_PKG).BuildTime=$$(date -u '+%Y-%m-%d_%H:%M:%S') \
			-X $(OFFLINELAB_BOOTCONF_PKG).Commit=$(OFFLINELAB_BOOTCONF_VERSION)" \
		-trimpath -buildvcs=false \
		-o $(@D)/bin/bootconf ./cmd/bootconf/main.go
endef

define OFFLINELAB_BOOTCONF_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/bin/bootconf \
		$(TARGET_DIR)/usr/local/bin/bootconf

	$(INSTALL) -D -m 0644 $(OFFLINELAB_BOOTCONF_SRC_DIR)/systemd/service/bootconf.service \
		$(TARGET_DIR)/etc/systemd/system/bootconf.service

	$(INSTALL) -D -m 0644 $(@D)/systemd/service/offlinelab-sysusers.service \
		$(TARGET_DIR)/etc/systemd/system/offlinelab-sysusers.service

	$(INSTALL) -D -m 0644 $(@D)/systemd/service/offlinelab-tempfiles.service \
		$(TARGET_DIR)/etc/systemd/system/offlinelab-tempfiles.service

	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants

	ln -sf /etc/systemd/system/bootconf.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/bootconf.service

	ln -sf /etc/systemd/system/offlinelab-sysusers.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/offlinelab-sysusers.service

	ln -sf /etc/systemd/system/offlinelab-tempfiles.service \
	$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/offlinelab-tempfiles.service

	mkdir -p $(TARGET_DIR)/data/config/tempfiles  $(TARGET_DIR)/data/config/sysusers

	cp $(OFFLINELAB_BOOTCONF_SRC_DIR)/bootconf.yaml.example $(BINARIES_DIR)/bootconf.yaml.example
endef

$(eval $(generic-package))
