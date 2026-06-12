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
# offlinelab-framework
#
################################################################################

OFFLINELAB_FRAMEWORK_VERSION = $(call qstrip,$(BR2_PACKAGE_OFFLINELAB_FRAMEWORK_VERSION))
OFFLINELAB_FRAMEWORK_SITE    = $(call github,offline-lab,framework,$(OFFLINELAB_FRAMEWORK_VERSION))
OFFLINELAB_FRAMEWORK_LICENSE = AGPL-3.0-only

OFFLINELAB_FRAMEWORK_DEPENDENCIES = \
	bash \
	file \
	jq \
	ncurses \
	libcurl \
	openssl \
	rauc \
	wpa_supplicant \
	iproute2 \
	fzf

define OFFLINELAB_FRAMEWORK_INSTALL_TARGET_CMDS
	# Library modules
	$(INSTALL) -d $(TARGET_DIR)/usr/lib/framework/library
	$(foreach cmd,$(wildcard $(@D)/src/library/*),\
		$(INSTALL) -m 0755 $(cmd) $(TARGET_DIR)/usr/lib/framework/library/$(notdir $(cmd));)

	# Executables
	$(INSTALL) -d $(TARGET_DIR)/usr/lib/framework/bin
	$(foreach cmd,$(wildcard $(@D)/src/bin/*),\
		$(INSTALL) -m 0755 $(cmd) $(TARGET_DIR)/usr/lib/framework/bin/$(notdir $(cmd));)

	# boxctl-su command allowlist
	$(INSTALL) -D -m 0644 $(@D)/etc/boxctl/su.conf \
		$(TARGET_DIR)/etc/boxctl/su.conf

	# PATH entry so scripts can do: source framework
	$(INSTALL) -d $(TARGET_DIR)/etc/profile.d
	printf 'export PATH="/usr/lib/framework/bin:$${PATH}"\nalias ssh=dbclient\n' \
		> $(TARGET_DIR)/etc/profile.d/framework.sh
endef

$(eval $(generic-package))
