################################################################################
#         ____  ___________               __          __                       #
#        / __ \/ __/ __/ (_)___  ___     / /   ____ `/ /_                      #
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
# offlinelab-testing
#
# Dev/test user credentials. Installs SSH keys, sudo rules, and home
# directories for admin (uid 1000) and testuser (uid 1001).
#
# Do NOT include in production builds.
#
################################################################################

OFFLINELAB_TESTING_VERSION     = 1.0
OFFLINELAB_TESTING_SITE        = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-testing/src
OFFLINELAB_TESTING_SITE_METHOD = local
OFFLINELAB_TESTING_LICENSE     = AGPL-3.0-only

OFFLINELAB_TESTING_DEPENDENCIES = offlinelab-base

OFFLINELAB_TESTING_USERS = \
	admin 1000 admin 1000 ! /home/admin /bin/bash sudo,systemd-journal Admin \
	testuser 1001 testuser 1001 ! /home/testuser /bin/bash sudo,systemd-journal Testuser

OFFLINELAB_TESTING_PERMISSIONS = \
	/home/admin d 0755 1000 1000 - - - - - \
	/home/admin/.ssh d 0700 1000 1000 - - - - - \
	/home/admin/.ssh/authorized_keys f 0600 1000 1000 - - - - - \
	/home/testuser d 0755 1001 1001 - - - - - \
	/home/testuser/.ssh d 0700 1001 1001 - - - - - \
	/home/testuser/.ssh/authorized_keys f 0600 1001 1001 - - - - -

# Board-specific bootconf template: bootconf-<board>.yaml if present, else bootconf.yaml.
OFFLINELAB_TESTING_BOARD = $(call qstrip,$(BR2_PACKAGE_OFFLINELAB_TESTING_BOARD))
OFFLINELAB_TESTING_BOOTCONF_TEMPLATE = \
	$(if $(wildcard $(@D)/bootconf-$(OFFLINELAB_TESTING_BOARD).yaml),\
		$(@D)/bootconf-$(OFFLINELAB_TESTING_BOARD).yaml,\
		$(@D)/bootconf.yaml)

define OFFLINELAB_TESTING_INSTALL_TARGET_CMDS
	# admin — SSH key, home dir, sudoers, bashrc, admin-bin PATH
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/home/admin
	$(INSTALL) -d -m 0700 $(TARGET_DIR)/home/admin/.ssh
	echo "$(call qstrip,$(BR2_PACKAGE_OFFLINELAB_TESTING_ADMIN_PUBKEY))" \
		> $(TARGET_DIR)/home/admin/.ssh/authorized_keys
	$(INSTALL) -D -m 0440 $(@D)/sudoers/admin \
		$(TARGET_DIR)/etc/sudoers.d/admin

	# testuser — SSH key from Kconfig, home dir, passwordless sudoers
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/home/testuser
	$(INSTALL) -d -m 0700 $(TARGET_DIR)/home/testuser/.ssh
	echo "$(call qstrip,$(BR2_PACKAGE_OFFLINELAB_TESTING_TESTUSER_PUBKEY))" \
		> $(TARGET_DIR)/home/testuser/.ssh/authorized_keys
	$(INSTALL) -D -m 0440 $(@D)/sudoers/testuser \
		$(TARGET_DIR)/etc/sudoers.d/testuser

	# bootconf.yaml — use board-specific template if present, else default.
	# Baked into data.ext4 at /data/config/bootconf.yaml by post-image-lib.sh.
	sed \
		-e 's|@@WIFI_ENABLED@@|$(if $(call qstrip,$(BR2_PACKAGE_OFFLINELAB_TESTING_WIFI_SSID)),true,false)|g' \
		-e 's|@@WIFI_SSID@@|$(call qstrip,$(BR2_PACKAGE_OFFLINELAB_TESTING_WIFI_SSID))|g' \
		-e 's|@@WIFI_PASSWORD_HASH@@|$(call qstrip,$(BR2_PACKAGE_OFFLINELAB_TESTING_WIFI_PASSWORD_HASH))|g' \
		-e 's|@@WIFI_COUNTRY@@|$(call qstrip,$(BR2_PACKAGE_OFFLINELAB_TESTING_WIFI_COUNTRY))|g' \
		-e 's|@@TESTUSER_PUBKEY@@|$(call qstrip,$(BR2_PACKAGE_OFFLINELAB_TESTING_TESTUSER_PUBKEY))|g' \
		$(OFFLINELAB_TESTING_BOOTCONF_TEMPLATE) \
		> $(BINARIES_DIR)/bootconf.yaml
endef

$(eval $(generic-package))
