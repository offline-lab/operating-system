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
# shellcheck shell=bash
#
# QEMU arm64 build script for running on a Linux build host.
# Uses a separate output directory (~/buildroot-qemu) so it can run
# alongside the pi-zero-2w build without clobbering its output.
#
# Expects: buildroot at ~/buildroot, br2-external at ~/work/br2-external
#
set -e -u -o pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

require_tools nproc ccache make date cp

NPROC="$(nproc)"
export MAKEFLAGS="-j${NPROC}"

BUILDROOT="${HOME}/buildroot"
BUILDROOT_OUT="${HOME}/buildroot-qemu"
WORK="${HOME}/work"
ARTIFACTS="${HOME}/artifacts/qemu"
DL_DIR="${HOME}/downloads"
CCACHE_DIR="${HOME}/.ccache"

export BR2_DL_DIR="${DL_DIR}"

if [[ ! -d "${BUILDROOT}" ]]; then
    log_err "buildroot not found at ${BUILDROOT}"
    exit 1
fi

mkdir -p "${ARTIFACTS}" "${DL_DIR}" "${CCACHE_DIR}" "${BUILDROOT_OUT}"

if ! ccache -s &>/dev/null; then
    ccache --max-size=15G
fi

# Remove stale bundle so post-image.sh always rebuilds it with the current kernel
rm -f "${BUILDROOT_OUT}/images/offlinelab-update.raucb"

make -C "${BUILDROOT}" O="${BUILDROOT_OUT}" BR2_EXTERNAL="${WORK}/br2-external" \
    offlinelab_qemu_arm64_defconfig

make -C "${BUILDROOT}" O="${BUILDROOT_OUT}" BR2_EXTERNAL="${WORK}/br2-external" \
    olddefconfig

make -C "${BUILDROOT}" O="${BUILDROOT_OUT}" BR2_EXTERNAL="${WORK}/br2-external" \
    BR2_CCACHE_DIR="${CCACHE_DIR}" \
    BR2_JLEVEL="${NPROC}" -j"${NPROC}"

log "Copying artifacts to ${ARTIFACTS}..."
cp -v "${BUILDROOT_OUT}/images/qemu.img" "${ARTIFACTS}/"
cp -v "${BUILDROOT_OUT}/images/u-boot.bin" "${ARTIFACTS}/"
cp -v "${BUILDROOT_OUT}/images/Image" "${ARTIFACTS}/"
cp -v "${BUILDROOT_OUT}/images/rootfs.ext4" "${ARTIFACTS}/"
cp -v "${BUILDROOT_OUT}/images/initramfs.cpio.gz" "${ARTIFACTS}/"
cp -v "${BUILDROOT_OUT}/images/boot.scr" "${ARTIFACTS}/"
cp -v "${BUILDROOT_OUT}/images/kernel-a.img" "${ARTIFACTS}/"

if [[ -f "${BUILDROOT_OUT}/images/offlinelab-update.raucb" ]]; then
    cp -v "${BUILDROOT_OUT}/images/offlinelab-update.raucb" "${ARTIFACTS}/"
fi

log "QEMU build complete — artifacts at ${ARTIFACTS}"
