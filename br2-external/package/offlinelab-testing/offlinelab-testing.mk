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

# Both accounts are key-authenticated only; password field '!' means locked.
# Buildroot's mkusers script processes these under fakeroot, which is the
# correct place to set ownership — do not use chown in install hooks.
OFFLINELAB_TESTING_USERS = \
	admin    1000 admin    1000 ! /home/admin    /bin/bash sudo,systemd-journal Admin \
	testuser 1001 testuser 1001 ! /home/testuser /bin/bash sudo,systemd-journal Testuser

# File modes and ownership applied by makedevs under fakeroot, after install.
OFFLINELAB_TESTING_PERMISSIONS = \
	/home/admin                          d 0755 1000 1000 - - - - - \
	/home/admin/.ssh                     d 0700 1000 1000 - - - - - \
	/home/admin/.ssh/authorized_keys     f 0600 1000 1000 - - - - - \
	/home/testuser                       d 0755 1001 1001 - - - - - \
	/home/testuser/.ssh                  d 0700 1001 1001 - - - - - \
	/home/testuser/.ssh/authorized_keys  f 0600 1001 1001 - - - - -

OFFLINELAB_TESTING_BUILDER_PUBKEY := $(BR2_EXTERNAL_OFFLINELAB_PATH)/../.ssh/builder.pub

define OFFLINELAB_TESTING_INSTALL_TARGET_CMDS
	# admin — SSH key, home dir, sudoers, bashrc, admin-bin PATH
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/home/admin
	$(INSTALL) -d -m 0700 $(TARGET_DIR)/home/admin/.ssh
	echo "$(call qstrip,$(BR2_PACKAGE_OFFLINELAB_TESTING_ADMIN_KEY))" \
		> $(TARGET_DIR)/home/admin/.ssh/authorized_keys
	$(INSTALL) -D -m 0644 $(@D)/bashrc \
		$(TARGET_DIR)/home/admin/.bashrc
	$(INSTALL) -D -m 0440 $(@D)/sudoers/admin \
		$(TARGET_DIR)/etc/sudoers.d/admin
	$(INSTALL) -D -m 0644 /dev/null \
		$(TARGET_DIR)/etc/profile.d/admin-bin.sh
	printf 'export PATH="/data/home/admin/bin:$${PATH}"\n' \
		> $(TARGET_DIR)/etc/profile.d/admin-bin.sh

	# testuser — key from .ssh/builder.pub, home dir, passwordless sudoers
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/home/testuser
	$(INSTALL) -d -m 0700 $(TARGET_DIR)/home/testuser/.ssh
	cat "$(OFFLINELAB_TESTING_BUILDER_PUBKEY)" 2>/dev/null \
		> $(TARGET_DIR)/home/testuser/.ssh/authorized_keys \
		|| : > $(TARGET_DIR)/home/testuser/.ssh/authorized_keys
	$(INSTALL) -D -m 0440 $(@D)/sudoers/testuser \
		$(TARGET_DIR)/etc/sudoers.d/testuser
endef

$(eval $(generic-package))
