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
# offlinelab-ssh
#
################################################################################

OFFLINELAB_SSH_VERSION     = 1.0
OFFLINELAB_SSH_SITE        = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-ssh/src
OFFLINELAB_SSH_SITE_METHOD = local
OFFLINELAB_SSH_LICENSE     = AGPL-3.0-only
OFFLINELAB_SSH_DEPENDENCIES = dropbear

define OFFLINELAB_SSH_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/systemd/service/dropbear.service \
		$(TARGET_DIR)/etc/systemd/system/dropbear.service
	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants
	ln -sf /etc/systemd/system/dropbear.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/dropbear.service

endef

$(eval $(generic-package))
