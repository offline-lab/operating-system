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
# offlinelab-base
#
################################################################################

OFFLINELAB_BASE_VERSION = 1.0
OFFLINELAB_BASE_SITE = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-base/src
OFFLINELAB_BASE_SITE_METHOD = local

OFFLINELAB_BASE_DEPENDENCIES = \
	bash \
	coreutils \
	e2fsprogs \
	parted \
	systemd

define OFFLINELAB_SPLASH_GENERATE
	@COMMON_DIR="$(BR2_EXTERNAL_OFFLINELAB_PATH)/boards/common"; \
	SVG="$${COMMON_DIR}/splash.svg"; \
	PNG="$${COMMON_DIR}/splash.png"; \
	if [ -f "$${SVG}" ] && command -v rsvg-convert >/dev/null 2>&1; then \
		VERSION=$$(date +%Y%m%d); \
		TMP=$$(mktemp); \
		sed "s/@@VERSION@@/$${VERSION}/g" "$${SVG}" > "$${TMP}"; \
		rsvg-convert -w 1920 -h 1080 "$${TMP}" -o "$${PNG}"; \
		rm -f "$${TMP}"; \
		echo "splash: generated $${PNG} (version $${VERSION})"; \
	elif [ -f "$${SVG}" ]; then \
		echo "splash: WARNING: rsvg-convert not found, using existing PNG" >&2; \
	fi
endef
PSPLASH_PRE_BUILD_HOOKS += OFFLINELAB_SPLASH_GENERATE

define OFFLINELAB_BASE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/etc/systemd/system/local-fs.target.wants
	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants
	mkdir -p $(TARGET_DIR)/etc/systemd/system/sysinit.target.wants
	mkdir -p $(TARGET_DIR)/etc/systemd/system/getty.target.wants
	mkdir -p $(TARGET_DIR)/etc/systemd/network

	$(INSTALL) -D -m 0644 $(@D)/systemd/mount/boot-firmware.mount \
		$(TARGET_DIR)/etc/systemd/system/boot-firmware.mount
	ln -sf /etc/systemd/system/boot-firmware.mount \
		$(TARGET_DIR)/etc/systemd/system/local-fs.target.wants/boot-firmware.mount

	$(INSTALL) -D -m 0644 $(@D)/systemd/service/expand-data.service \
		$(TARGET_DIR)/etc/systemd/system/expand-data.service
	ln -sf /etc/systemd/system/expand-data.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/expand-data.service

	$(INSTALL) -D -m 0644 $(@D)/systemd/service/fake-hwclock.service \
		$(TARGET_DIR)/etc/systemd/system/fake-hwclock.service
	ln -sf /etc/systemd/system/fake-hwclock.service \
		$(TARGET_DIR)/etc/systemd/system/sysinit.target.wants/fake-hwclock.service

	$(INSTALL) -D -m 0755 $(@D)/init-expand-data \
		$(TARGET_DIR)/usr/local/bin/init-expand-data
	$(INSTALL) -D -m 0755 $(@D)/init-fake-hwclock \
		$(TARGET_DIR)/usr/local/bin/init-fake-hwclock

	$(INSTALL) -D -m 0644 $(@D)/systemd/service/power-profile.service \
		$(TARGET_DIR)/etc/systemd/system/power-profile.service
	ln -sf /etc/systemd/system/power-profile.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/power-profile.service

	$(INSTALL) -D -m 0644 $(@D)/systemd/service/psplash-quit.service \
		$(TARGET_DIR)/etc/systemd/system/psplash-quit.service
	ln -sf /etc/systemd/system/psplash-quit.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/psplash-quit.service

	ln -sf /lib/systemd/system/serial-getty@.service \
		"$(TARGET_DIR)/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service"
	ln -sf /lib/systemd/system/getty@.service \
		"$(TARGET_DIR)/etc/systemd/system/getty.target.wants/getty@tty1.service"

	echo ""                                          >  $(@D)/issue
	echo "Offline Lab OS"                            >> $(@D)/issue
	echo "---------------------------------------"   >> $(@D)/issue
	echo "Kernel:  $(LINUX_VERSION_PROBED)"          >> $(@D)/issue
	echo "Built:   $$(date +"%Y-%m-%d %H:%M")"      >> $(@D)/issue
	printf 'wlan0:   \\4{wlan0}\n'                   >> $(@D)/issue
	printf 'usb0:    \\4{usb0}\n'                    >> $(@D)/issue
	echo ""                                          >> $(@D)/issue
	$(INSTALL) -D -m 644 $(@D)/issue $(TARGET_DIR)/etc/issue
	$(INSTALL) -D -m 644 $(@D)/issue $(TARGET_DIR)/etc/issue.net

	$(INSTALL) -D -m 0440 $(@D)/sudoers/admin \
		$(TARGET_DIR)/etc/sudoers.d/admin

	# Admin home directory structure under /data (created at runtime by tmpfiles)
	$(INSTALL) -d $(TARGET_DIR)/etc/tmpfiles.d
	$(INSTALL) -m 0644 $(@D)/systemd/tmpfiles.d/offlinelab-admin.conf \
		$(TARGET_DIR)/etc/tmpfiles.d/offlinelab-admin.conf

	# Add /data/home/admin/bin to PATH for the admin user
	$(INSTALL) -d $(TARGET_DIR)/etc/profile.d
	printf 'export PATH="/data/home/admin/bin:$${PATH}"\n' \
		> $(TARGET_DIR)/etc/profile.d/admin-bin.sh
endef

$(eval $(generic-package))
