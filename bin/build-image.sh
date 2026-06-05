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
# Build a board image on the native Linux build host.
# Usage: build-image.sh <board>
#   board: pi-zero-2w, qemu-arm64, pi4, etc.
#
# Expects: buildroot at ~/buildroot, br2-external at ~/work/br2-external
#
set -e -u -o pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

require_tools nproc ccache make date

[[ "${#}" -eq 1 ]] || { log_err "Usage: build-image.sh <board>"; exit 1; }

BOARD="${1}"
NPROC="$(nproc)"
export MAKEFLAGS="-j${NPROC}"

BUILDROOT="${HOME}/buildroot"
WORK="${HOME}/work"
BUILDROOT_OUT="${HOME}/buildroot-${BOARD}"
ARTIFACTS="${HOME}/artifacts/${BOARD}"
DL_DIR="${HOME}/downloads"
CCACHE_DIR="${HOME}/.ccache"

DEFCONFIG="offlinelab_${BOARD//-/_}_defconfig"

export BR2_DL_DIR="${DL_DIR}"

if [[ ! -d "${BUILDROOT}" ]]; then
    log_err "buildroot not found at ${BUILDROOT}"
    exit 1
fi

mkdir -p "${ARTIFACTS}" "${DL_DIR}" "${CCACHE_DIR}" "${BUILDROOT_OUT}"

if ! ccache -s &>/dev/null; then
    ccache --max-size=15G
fi

# Find splash.svg — check board dir then family/<board>/ dir
SPLASH_SVG=""
SPLASH_PNG=""
for splash_dir in \
    "${WORK}/br2-external/boards/${BOARD}" \
    "${WORK}/br2-external/boards/"*"/${BOARD}"; do
    if [[ -f "${splash_dir}/splash.svg" ]]; then
        SPLASH_SVG="${splash_dir}/splash.svg"
        SPLASH_PNG="${splash_dir}/splash.png"
        break
    fi
done

if [[ -n "${SPLASH_SVG}" ]] && command -v rsvg-convert &>/dev/null; then
    splash_date="$(date +%Y%m%d)"
    "${WORK}/bin/gen-splash.sh" "${SPLASH_SVG}" "${SPLASH_PNG}" "${splash_date}"
    make -C "${BUILDROOT}" O="${BUILDROOT_OUT}" BR2_EXTERNAL="${WORK}/br2-external" psplash-dirclean
fi

# Remove stale bundle so post-image.sh always rebuilds it with the current kernel
rm -f "${BUILDROOT_OUT}/images/offlinelab-update.raucb"

make -C "${BUILDROOT}" O="${BUILDROOT_OUT}" BR2_EXTERNAL="${WORK}/br2-external" \
    "${DEFCONFIG}"

if [[ -f "${WORK}/.config" ]]; then
    "${BUILDROOT}/support/kconfig/merge_config.sh" \
        -m -r -O "${BUILDROOT_OUT}" \
        "${BUILDROOT_OUT}/.config" "${WORK}/.config"
fi

make -C "${BUILDROOT}" O="${BUILDROOT_OUT}" BR2_EXTERNAL="${WORK}/br2-external" \
    olddefconfig

make -C "${BUILDROOT}" O="${BUILDROOT_OUT}" BR2_EXTERNAL="${WORK}/br2-external" \
    BR2_CCACHE_DIR="${CCACHE_DIR}" \
    BR2_JLEVEL="${NPROC}" -j"${NPROC}"

log "Copying artifacts to ${ARTIFACTS}..."
cp -rv "${BUILDROOT_OUT}/images/"* "${ARTIFACTS}/"

if [[ -e "${BUILDROOT_OUT}/images/sdcard.img" ]] && command -v pigz &>/dev/null; then
    timestamp="$(date +%Y-%m-%d-%H%M%S)"
    pigz --force -9 "${BUILDROOT_OUT}/images/sdcard.img" --stdout \
        >"${ARTIFACTS}/offlinelab-${BOARD}-${timestamp}.img.gz"
fi

log "${BOARD} build complete — artifacts at ${ARTIFACTS}"
