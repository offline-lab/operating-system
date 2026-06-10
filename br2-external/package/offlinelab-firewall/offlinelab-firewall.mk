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
# offlinelab-firewall
#
################################################################################

OFFLINELAB_FIREWALL_VERSION     = 1.0
OFFLINELAB_FIREWALL_SITE        = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-firewall/src
OFFLINELAB_FIREWALL_SITE_METHOD = local
OFFLINELAB_FIREWALL_LICENSE     = AGPL-3.0-only
OFFLINELAB_FIREWALL_DEPENDENCIES = nftables systemd offlinelab-framework

define OFFLINELAB_FIREWALL_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/etc/firewall/rules.fw \
		$(TARGET_DIR)/etc/firewall/rules.fw

	$(INSTALL) -D -m 0644 $(@D)/systemd/service/firewall.service \
		$(TARGET_DIR)/etc/systemd/system/firewall.service
	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants
	ln -sf /etc/systemd/system/firewall.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/firewall.service

	$(INSTALL) -D -m 0755 $(@D)/firewall-init \
		$(TARGET_DIR)/usr/local/bin/firewall-init
	$(INSTALL) -D -m 0755 $(@D)/firewall-restore \
		$(TARGET_DIR)/usr/local/bin/firewall-restore
endef

$(eval $(generic-package))
