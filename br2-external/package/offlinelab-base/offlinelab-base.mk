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

OFFLINELAB_BASE_VERSION     = 1.0
OFFLINELAB_BASE_SITE        = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-base/src
OFFLINELAB_BASE_SITE_METHOD = local
OFFLINELAB_BASE_LICENSE     = AGPL-3.0-only

OFFLINELAB_BASE_DEPENDENCIES = \
	bash \
	coreutils \
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

	# Mount point directories for boot firmware and sysext/confext bind-mounts
	mkdir -p $(TARGET_DIR)/boot/firmware
	mkdir -p $(TARGET_DIR)/var/lib/extensions
	mkdir -p $(TARGET_DIR)/etc/extensions

	$(INSTALL) -D -m 0644 $(@D)/systemd/mount/boot-firmware.mount \
		$(TARGET_DIR)/etc/systemd/system/boot-firmware.mount
	ln -sf /etc/systemd/system/boot-firmware.mount \
		$(TARGET_DIR)/etc/systemd/system/local-fs.target.wants/boot-firmware.mount

	$(INSTALL) -D -m 0644 $(@D)/systemd/mount/tmp.mount \
		$(TARGET_DIR)/etc/systemd/system/tmp.mount
	ln -sf /etc/systemd/system/tmp.mount \
		$(TARGET_DIR)/etc/systemd/system/local-fs.target.wants/tmp.mount

	$(INSTALL) -D -m 0644 $(@D)/systemd/mount/var-lib-extensions.mount \
		$(TARGET_DIR)/etc/systemd/system/var-lib-extensions.mount
	ln -sf /etc/systemd/system/var-lib-extensions.mount \
		$(TARGET_DIR)/etc/systemd/system/sysinit.target.wants/var-lib-extensions.mount

	$(INSTALL) -D -m 0644 $(@D)/systemd/mount/etc-extensions.mount \
		$(TARGET_DIR)/etc/systemd/system/etc-extensions.mount
	ln -sf /etc/systemd/system/etc-extensions.mount \
		$(TARGET_DIR)/etc/systemd/system/sysinit.target.wants/etc-extensions.mount

	ln -sf /lib/systemd/system/systemd-sysext.service \
		$(TARGET_DIR)/etc/systemd/system/sysinit.target.wants/systemd-sysext.service
	ln -sf /lib/systemd/system/systemd-confext.service \
		$(TARGET_DIR)/etc/systemd/system/sysinit.target.wants/systemd-confext.service

	$(INSTALL) -D -m 0644 $(@D)/repart.d/10-data.conf \
		$(TARGET_DIR)/usr/lib/repart.d/10-data.conf

	$(INSTALL) -D -m 0644 $(@D)/systemd/service/clock-load.service \
		$(TARGET_DIR)/etc/systemd/system/clock-load.service
	ln -sf /etc/systemd/system/clock-load.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/clock-load.service

	$(INSTALL) -D -m 0644 $(@D)/systemd/service/clock-save.service \
		$(TARGET_DIR)/etc/systemd/system/clock-save.service
	ln -sf /etc/systemd/system/clock-save.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/clock-save.service

	$(INSTALL) -D -m 0644 $(@D)/systemd/service/persist-machine-id.service \
		$(TARGET_DIR)/etc/systemd/system/persist-machine-id.service
	ln -sf /etc/systemd/system/persist-machine-id.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/persist-machine-id.service

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
	echo "Built:   $$(date +"%Y-%m-%d %H:%M")"       >> $(@D)/issue
	printf 'wlan0:   \\4{wlan0}\n'                   >> $(@D)/issue
	printf 'usb0:    \\4{usb0}\n'                    >> $(@D)/issue
	echo ""                                          >> $(@D)/issue

	$(INSTALL) -D -m 0644 $(@D)/issue $(TARGET_DIR)/etc/issue
	$(INSTALL) -D -m 0644 $(@D)/issue $(TARGET_DIR)/etc/issue.net

	$(INSTALL) -D -m 0644 $(@D)/skel/bashrc \
		$(TARGET_DIR)/etc/skel/.bashrc
	mkdir -p $(TARGET_DIR)/root
	rm -f $(TARGET_DIR)/root/.bashrc
	ln -s /etc/skel/.bashrc $(TARGET_DIR)/root/.bashrc

	# Sudo: system-wide defaults, sudo group rule, and include for bootconf-managed rules
	$(INSTALL) -D -m 0440 $(@D)/sudoers/defaults.conf \
		$(TARGET_DIR)/etc/sudoers.d/defaults.conf
	$(INSTALL) -D -m 0440 $(@D)/sudoers/sudo-group.conf \
		$(TARGET_DIR)/etc/sudoers.d/sudo-group.conf
	$(INSTALL) -D -m 0440 $(@D)/sudoers/include.conf \
		$(TARGET_DIR)/etc/sudoers.d/include.conf

	# Tmpfiles: create /data subdirs used by bootconf at runtime
	$(INSTALL) -d $(TARGET_DIR)/etc/tmpfiles.d
	$(INSTALL) -m 0644 $(@D)/systemd/tmpfiles.d/offlinelab-base.conf \
		$(TARGET_DIR)/etc/tmpfiles.d/offlinelab-base.conf
endef

$(eval $(generic-package))
