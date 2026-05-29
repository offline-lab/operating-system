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
# offlinelab-portable
#
################################################################################

OFFLINELAB_PORTABLE_VERSION = 1.0
OFFLINELAB_PORTABLE_SITE = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-portable/src
OFFLINELAB_PORTABLE_SITE_METHOD = local

OFFLINELAB_PORTABLE_DEPENDENCIES = systemd

define OFFLINELAB_PORTABLE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/systemd/modules-load.d/99-offlinelab-portable.conf \
		$(TARGET_DIR)/etc/modules-load.d/99-offlinelab-portable.conf

	ln -sfn /data/apps $(TARGET_DIR)/var/lib/portables
	ln -sfn /data/extensions $(TARGET_DIR)/var/lib/extensions
	ln -sfn /data/confexts $(TARGET_DIR)/var/lib/confexts
endef

$(eval $(generic-package))
