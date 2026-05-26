#!/usr/bin/env bash
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
