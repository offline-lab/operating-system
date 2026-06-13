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
# offlinelab-usb-gadget
#
################################################################################

OFFLINELAB_USB_GADGET_VERSION     = 1.0
OFFLINELAB_USB_GADGET_SITE        = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-usb-gadget/src
OFFLINELAB_USB_GADGET_SITE_METHOD = local
OFFLINELAB_USB_GADGET_LICENSE     = AGPL-3.0-only

define OFFLINELAB_USB_GADGET_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/systemd/service/usb-gadget.service \
		$(TARGET_DIR)/etc/systemd/system/usb-gadget.service
	$(INSTALL) -D -m 0644 \
		$(@D)/systemd/system/serial-getty@ttyGS0.service.d/wait-for-gadget.conf \
		$(TARGET_DIR)/etc/systemd/system/serial-getty@ttyGS0.service.d/wait-for-gadget.conf
	$(INSTALL) -D -m 0644 $(@D)/systemd/network/usb0.network \
		$(TARGET_DIR)/etc/systemd/network/usb0.network
	$(INSTALL) -D -m 0644 $(@D)/systemd/modules-load.d/99-offlinelab-usb-gadget.conf \
		$(TARGET_DIR)/etc/modules-load.d/99-offlinelab-usb-gadget.conf
	$(INSTALL) -D -m 0755 $(@D)/init-usb-gadget \
		$(TARGET_DIR)/usr/local/bin/init-usb-gadget
	mkdir -p $(TARGET_DIR)/etc/systemd/system/sysinit.target.wants
	ln -sf /etc/systemd/system/usb-gadget.service \
		$(TARGET_DIR)/etc/systemd/system/sysinit.target.wants/usb-gadget.service
	mkdir -p $(TARGET_DIR)/etc/systemd/system/getty.target.wants
	ln -sf /lib/systemd/system/serial-getty@.service \
		"$(TARGET_DIR)/etc/systemd/system/getty.target.wants/serial-getty@ttyGS0.service"
endef

$(eval $(generic-package))
