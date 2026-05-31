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
# offlinelab-wifi
#
################################################################################

OFFLINELAB_WIFI_VERSION = 1.0
OFFLINELAB_WIFI_SITE = $(BR2_EXTERNAL_OFFLINELAB_PATH)/package/offlinelab-wifi/src
OFFLINELAB_WIFI_SITE_METHOD = local
OFFLINELAB_WIFI_DEPENDENCIES = wpa_supplicant

define OFFLINELAB_WIFI_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/systemd/service/provision-wifi.service \
		$(TARGET_DIR)/etc/systemd/system/provision-wifi.service
	$(INSTALL) -D -m 0644 $(@D)/systemd/service/wifi-setup.service \
		$(TARGET_DIR)/etc/systemd/system/wifi-setup.service
	$(INSTALL) -D -m 0644 $(@D)/systemd/network/wlan0.network \
		$(TARGET_DIR)/etc/systemd/network/wlan0.network
	$(INSTALL) -D -m 0755 $(@D)/init-provision-wifi \
		$(TARGET_DIR)/usr/local/bin/init-provision-wifi
	$(INSTALL) -D -m 0755 $(@D)/init-wifi-setup \
		$(TARGET_DIR)/usr/local/bin/init-wifi-setup
	$(INSTALL) -D -m 0644 $(@D)/config/02w-wifi-fix.conf \
		$(TARGET_DIR)/etc/modprobe.d/02w-wifi-fix.conf
	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants
	ln -sf /etc/systemd/system/provision-wifi.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/provision-wifi.service
	ln -sf /etc/systemd/system/wifi-setup.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/wifi-setup.service

	if [ "$(BR2_PACKAGE_OFFLINELAB_WIFI_WPA_CREATE)" = y ]; then \
		mkdir -p $(BINARIES_DIR)/config; \
		if [ -n "$(call qstrip,$(BR2_PACKAGE_OFFLINELAB_WIFI_WPA_SSID))" ] && \
		   [ -n "$(call qstrip,$(BR2_PACKAGE_OFFLINELAB_WIFI_WPA_PASSWORD))" ]; then \
			{ \
				printf 'ctrl_interface=DIR=/run/wpa_supplicant GROUP=netdev\n'; \
				printf 'update_config=1\n'; \
				printf 'country=%s\n\n' "$(call qstrip,$(BR2_PACKAGE_OFFLINELAB_WIFI_WPA_COUNTRY))"; \
				wpa_passphrase \
					"$(call qstrip,$(BR2_PACKAGE_OFFLINELAB_WIFI_WPA_SSID))" \
					"$(call qstrip,$(BR2_PACKAGE_OFFLINELAB_WIFI_WPA_PASSWORD))"; \
			} > "$(BINARIES_DIR)/config/wpa_supplicant.conf"; \
		fi \
	fi
endef

$(eval $(generic-package))
