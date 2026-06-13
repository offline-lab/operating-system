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
# offlinelab-resources
#
################################################################################

OFFLINELAB_RESOURCES_VERSION     = 1.0
OFFLINELAB_RESOURCES_SITE        = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-resources/src
OFFLINELAB_RESOURCES_SITE_METHOD = local
OFFLINELAB_RESOURCES_LICENSE     = AGPL-3.0-only

OFFLINELAB_RESOURCES_DEPENDENCIES = offlinelab-framework jq

define OFFLINELAB_RESOURCES_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/init-resources \
		$(TARGET_DIR)/usr/local/bin/init-resources
	$(INSTALL) -D -m 0644 $(@D)/systemd/service/offlinelab-resources.service \
		$(TARGET_DIR)/etc/systemd/system/offlinelab-resources.service
	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants
	ln -sf /etc/systemd/system/offlinelab-resources.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/offlinelab-resources.service
endef

$(eval $(generic-package))
