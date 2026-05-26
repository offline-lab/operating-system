################################################################################
#
# offlinelab-disco
#
# Service discovery, NSS, and time sync for offline networks.
# Source fetched from GitHub at build time — nothing stored in br2-builder.
#
################################################################################

OFFLINELAB_DISCO_VERSION = $(call qstrip,$(BR2_PACKAGE_OFFLINELAB_DISCO_VERSION))
OFFLINELAB_DISCO_SITE = https://github.com/offline-lab/disco.git
OFFLINELAB_DISCO_SITE_METHOD = git

# TODO: uncomment and implement when disco build is ready
# OFFLINELAB_DISCO_DEPENDENCIES = host-go systemd

# Placeholder — actual build/install targets will be added when disco
# source stabilizes. The package skeleton is here so Config.in options
# and directory structure are ready for integration.

# define OFFLINELAB_DISCO_BUILD_CMDS
# endef

# define OFFLINELAB_DISCO_INSTALL_TARGET_CMDS
# endef

$(eval $(generic-package))
