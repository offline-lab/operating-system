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
# offlinelab-zram
#
################################################################################

OFFLINELAB_ZRAM_VERSION = 1.0
OFFLINELAB_ZRAM_SITE = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-zram/src
OFFLINELAB_ZRAM_SITE_METHOD = local

define OFFLINELAB_ZRAM_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/systemd/service/zram-swap.service \
		$(TARGET_DIR)/etc/systemd/system/zram-swap.service
	$(INSTALL) -D -m 0644 $(@D)/systemd/modules-load.d/99-offlinelab-zram.conf \
		$(TARGET_DIR)/etc/modules-load.d/99-offlinelab-zram.conf
	$(INSTALL) -D -m 0755 $(@D)/config/zram-swap.sh \
		$(TARGET_DIR)/usr/local/bin/zram-swap.sh
	$(INSTALL) -D -m 0644 $(@D)/config/zram-swap.config \
		$(TARGET_DIR)/etc/default/zram-swap
	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants
	ln -sf /etc/systemd/system/zram-swap.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/zram-swap.service
endef

$(eval $(generic-package))
