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
# Native build script for running on a Linux build host (no Docker).
# Expects: buildroot at ~/buildroot, br2-external at ~/work/br2-external
#
set -e -u -o pipefail

NPROC="$(nproc)"
export MAKEFLAGS="-j${NPROC}"

BUILDROOT="${HOME}/buildroot"
WORK="${HOME}/work"
ARTIFACTS="${HOME}/artifacts"
DL_DIR="${HOME}/downloads"
CCACHE_DIR="${HOME}/.ccache"

export BR2_DL_DIR="${DL_DIR}"

if [[ ! -d "${BUILDROOT}" ]]; then
    echo "ERROR: buildroot not found at ${BUILDROOT}"
    exit 1
fi

mkdir -p "${ARTIFACTS}" "${DL_DIR}" "${CCACHE_DIR}"

if ! ccache -s &>/dev/null; then
    ccache --max-size=15G
fi

SPLASH_SVG="${WORK}/br2-external/boards/pi-zero-2w/splash.svg"
SPLASH_PNG="${WORK}/br2-external/boards/pi-zero-2w/splash.png"
if [[ -f "${SPLASH_SVG}" ]] && command -v rsvg-convert &>/dev/null; then
    "${WORK}/bin/gen-splash.sh" "${SPLASH_SVG}" "${SPLASH_PNG}" "$(date +%Y%m%d)"
fi

make -C "${BUILDROOT}" BR2_EXTERNAL="${WORK}/br2-external" offlinelab_pi_zero_2w_defconfig

if [[ -f "${WORK}/.config" ]]; then
    "${BUILDROOT}/support/kconfig/merge_config.sh" \
        -m -r -O "${BUILDROOT}" \
        "${BUILDROOT}/.config" "${WORK}/.config"
fi

make -C "${BUILDROOT}" BR2_EXTERNAL="${WORK}/br2-external" olddefconfig

make -C "${BUILDROOT}" BR2_EXTERNAL="${WORK}/br2-external" \
    BR2_CCACHE_DIR="${CCACHE_DIR}" \
    BR2_JLEVEL="${NPROC}" -j"${NPROC}"

timestamp="$(date +%Y-%m-%d-%H%M%S)"

if [[ -e "${BUILDROOT}/output/images/sdcard.img" ]]; then
    pigz --force -9 "${BUILDROOT}/output/images/sdcard.img" --stdout \
        > "${ARTIFACTS}/offlinelab-sdcard-${timestamp}.img.gz"
fi

cp -rv "${BUILDROOT}/output/images/"* "${ARTIFACTS}/"
