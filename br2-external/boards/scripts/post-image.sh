#!/usr/bin/env bash
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

# vi: ft=bash
# shellcheck shell=bash disable=SC1090,SC1091,SC2155
set -e -o pipefail

export BUILD_DIR="${BUILD_DIR:-}"
export TARGET_DIR="${TARGET_DIR:-}"
export HOST_DIR="${HOST_DIR:-}"
export BINARIES_DIR="${BINARIES_DIR:-}"
export BR2_EXTERNAL_OFFLINELAB_PATH="${BR2_EXTERNAL_OFFLINELAB_PATH:-}"
export BOARD_DIR="${2}"
export COMMON_DIR="${BR2_EXTERNAL_OFFLINELAB_PATH}/boards/common"
export GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

source "${BOARD_DIR}/meta"
function prune_overlays() { :; }   # no-op default; RPi hook overrides this
source "${3}"   # hook: defines gen_config(), board_post_build(), BOOT_CMD_FILE

source "${BR2_EXTERNAL_OFFLINELAB_PATH}/boards/scripts/post-image-lib.sh"

build_initramfs && sync
build_boot_scr && sync
build_kernel_squashfs && sync
create_overlay && sync
create_data && sync
prune_overlays && sync
assemble && sync
build_rauc_bundle && sync
exit $?
