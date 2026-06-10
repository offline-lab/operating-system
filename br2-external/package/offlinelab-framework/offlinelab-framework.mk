################################################################################
#
# offlinelab-framework
#
################################################################################

# Switch to SITE_METHOD = git once the remote is published.
# For local dev, SITE_METHOD = local points at the sibling ../framework repo.
OFFLINELAB_FRAMEWORK_VERSION     = 1.0
OFFLINELAB_FRAMEWORK_SITE        = $(BR2_EXTERNAL_OFFLINELAB_PATH)/../../framework
OFFLINELAB_FRAMEWORK_SITE_METHOD = local
OFFLINELAB_FRAMEWORK_LICENSE     = AGPL-3.0-only

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
	$(INSTALL) -m 0644 $(@D)/src/library/*.sh $(TARGET_DIR)/usr/lib/framework/library/

	# Executables — bin/ is host-only tooling; src/bin/ is the on-device runtime
	$(INSTALL) -d $(TARGET_DIR)/usr/lib/framework/bin
	$(INSTALL) -m 0755 $(@D)/src/bin/chronic   $(TARGET_DIR)/usr/lib/framework/bin/
	$(INSTALL) -m 0755 $(@D)/src/bin/framework $(TARGET_DIR)/usr/lib/framework/bin/
	$(foreach cmd,$(wildcard $(@D)/src/bin/boxctl*),\
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
