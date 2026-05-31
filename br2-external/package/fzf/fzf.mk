################################################################################
#
# fzf — command-line fuzzy finder (prebuilt static binary)
#
# Source: https://github.com/junegunn/fzf
# License: MIT
#
# Downloads the official prebuilt musl static binary for the target arch.
# No Go toolchain required at build time.
#
################################################################################

FZF_VERSION = 0.61.1
FZF_LICENSE = MIT
FZF_LICENSE_FILES = LICENSE

# Map buildroot arch to fzf release arch
ifeq ($(BR2_aarch64),y)
FZF_ARCH = arm64
else ifeq ($(BR2_arm),y)
FZF_ARCH = armv7
else ifeq ($(BR2_x86_64),y)
FZF_ARCH = amd64
else
$(error fzf: unsupported architecture — add a mapping in fzf.mk)
endif

FZF_SITE = https://github.com/junegunn/fzf/releases/download/v$(FZF_VERSION)
FZF_SOURCE = fzf-$(FZF_VERSION)-linux_$(FZF_ARCH).tar.gz
# Tarball has no wrapping directory — don't strip path components
FZF_STRIP_COMPONENTS = 0

# Verify these hashes against the release page before use.
# https://github.com/junegunn/fzf/releases/tag/v0.61.1
#
# Run: sha256sum fzf-0.61.1-linux_<arch>.tar.gz
# Then update buildroot/package/fzf/fzf.hash accordingly.

define FZF_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/fzf $(TARGET_DIR)/usr/bin/fzf
endef

$(eval $(generic-package))
