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
# offlinelab-update
#
################################################################################

OFFLINELAB_UPDATE_VERSION = 1.0
OFFLINELAB_UPDATE_SITE = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-update/src
OFFLINELAB_UPDATE_SITE_METHOD = local

OFFLINELAB_UPDATE_DEPENDENCIES = \
	rauc \
	uboot-tools

define OFFLINELAB_UPDATE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/etc/rauc
	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants

	$(INSTALL) -D -m 0644 $(@D)/rauc/system.conf \
		$(TARGET_DIR)/etc/rauc/system.conf

	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_OFFLINELAB_PATH)/../.rauc/ca.cert.pem \
		$(TARGET_DIR)/etc/rauc/keyring.pem

	$(INSTALL) -D -m 0644 $(@D)/rauc/fw_env.config \
		$(TARGET_DIR)/etc/fw_env.config

	$(INSTALL) -D -m 0644 $(@D)/systemd/service/rauc-mark-good.service \
		$(TARGET_DIR)/etc/systemd/system/rauc-mark-good.service
	ln -sf /etc/systemd/system/rauc-mark-good.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/rauc-mark-good.service

	$(INSTALL) -D -m 0755 $(@D)/init-usb-update \
		$(TARGET_DIR)/usr/local/bin/init-usb-update

	$(INSTALL) -D -m 0644 $(@D)/systemd/service/usb-update@.service \
		$(TARGET_DIR)/etc/systemd/system/usb-update@.service

	$(INSTALL) -D -m 0644 $(@D)/udev/99-offlinelab-usb-update.rules \
		$(TARGET_DIR)/usr/lib/udev/rules.d/99-offlinelab-usb-update.rules
endef

$(eval $(generic-package))
