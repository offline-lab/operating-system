################################################################################
#
# offlinelab-framework
#
################################################################################

OFFLINELAB_FRAMEWORK_VERSION = 1.0
OFFLINELAB_FRAMEWORK_SITE = $(BR2_EXTERNAL_OFFLINELAB_PATH)/../framework
OFFLINELAB_FRAMEWORK_SITE_METHOD = local

OFFLINELAB_FRAMEWORK_DEPENDENCIES = \
	bash \
	file \
	jq \
	ncurses \
	libcurl \
	rauc \
	wpa_supplicant \
	iproute2 \
	fzf

define OFFLINELAB_FRAMEWORK_INSTALL_TARGET_CMDS
	# Library modules
	$(INSTALL) -d $(TARGET_DIR)/usr/lib/framework
	$(INSTALL) -m 0644 $(@D)/library/*.sh $(TARGET_DIR)/usr/lib/framework/

	# Executables — dev-setup and tools are host-only, not included
	$(INSTALL) -d $(TARGET_DIR)/usr/lib/framework/bin
	$(INSTALL) -m 0755 $(@D)/bin/chronic   $(TARGET_DIR)/usr/lib/framework/bin/
	$(INSTALL) -m 0755 $(@D)/bin/framework $(TARGET_DIR)/usr/lib/framework/bin/
	$(foreach cmd,$(wildcard $(@D)/bin/labctl*),\
		$(INSTALL) -m 0755 $(cmd) $(TARGET_DIR)/usr/lib/framework/bin/$(notdir $(cmd));)

	# labctl-su command allowlist
	$(INSTALL) -D -m 0644 $(@D)/etc/labctl/su.conf \
		$(TARGET_DIR)/etc/labctl/su.conf

	# PATH entry so scripts can do: source framework
	$(INSTALL) -d $(TARGET_DIR)/etc/profile.d
	printf 'export PATH="/usr/lib/framework/bin:$${PATH}"\nalias ssh=dbclient\n' \
		> $(TARGET_DIR)/etc/profile.d/framework.sh
endef

$(eval $(generic-package))
