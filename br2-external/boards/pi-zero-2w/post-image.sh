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
# shellcheck shell=bash disable=SC2155
set -e -o pipefail

export BUILD_DIR="${BUILD_DIR:-}"
export TARGET_DIR="${TARGET_DIR:-}"
export HOST_DIR="${HOST_DIR:-}"
export BINARIES_DIR="${BINARIES_DIR:-}"
export BR2_EXTERNAL_OFFLINELAB_PATH="${BR2_EXTERNAL_OFFLINELAB_PATH:-}"
export BOARD_DIR="$(dirname "${0}")"
export GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

function build_initramfs() {
    local tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}"' RETURN

    mkdir -p "${tmpdir}"/{bin,sbin,etc,proc,sys,dev,mnt,newroot,data,tmp,overlay}

    cp "${TARGET_DIR}/bin/busybox" "${tmpdir}/bin/busybox"
    chmod 755 "${tmpdir}/bin/busybox"

    for cmd in sh mount umount mkdir switch_root cat echo mdev sleep; do
        ln -s busybox "${tmpdir}/bin/${cmd}"
    done

    cp "${BOARD_DIR}/initramfs/init" "${tmpdir}/init"
    chmod 755 "${tmpdir}/init"

    (cd "${tmpdir}" && find . | cpio -o -H newc 2>/dev/null | gzip -9 \
        > "${BINARIES_DIR}/initramfs.cpio.gz")
}

function build_boot_scr() {
    "${HOST_DIR}/bin/mkimage" -C none -A arm64 -T script \
        -d "${BOARD_DIR}/uboot/boot.cmd" "${BINARIES_DIR}/boot.scr"
}

function build_kernel_squashfs() {
    local tmpdir="$(mktemp -d)"
    cp "${BINARIES_DIR}/Image" "${tmpdir}/Image"
    "${HOST_DIR}/bin/mksquashfs" "${tmpdir}" "${BINARIES_DIR}/kernel-a.img" \
        -noappend -comp lzo -b 131072 -quiet
    rm -rf "${tmpdir}"
}

function gen_config() {
    local output="${1}"
    local -a files=(
        u-boot.bin
        boot.scr
        initramfs.cpio.gz
        rpi-firmware/bootcode.bin
        rpi-firmware/cmdline.txt
        rpi-firmware/config.txt
        rpi-firmware/start.elf
        rpi-firmware/fixup.dat
        rpi-firmware/overlays
    )

    for i in "${BINARIES_DIR}"/*.dtb "${BINARIES_DIR}"/rpi-firmware/*; do
        [[ -e "${i}" ]] || continue
        file="${i#"${BINARIES_DIR}"/}"
        if printf '%s\n' "${files[@]}" | grep -q -- "^${file}$"; then continue; fi
        files+=("${file}")
    done

    if [[ -d "${BINARIES_DIR}/config" ]] && [[ -n "$(ls -A "${BINARIES_DIR}/config" 2>/dev/null)" ]]; then
        files+=("config")
    fi

    local boot_files="$(printf '\\t\\t\\t"%s",\\n' "${files[@]}")"
    sed "s|#BOOT_FILES#|${boot_files}|" "${BOARD_DIR}/genimage.cfg.in" > "${output}"
}

function create_overlay() {
    local tmpdir="$(mktemp -d)"
    mkdir -p "${tmpdir}/a/upper" "${tmpdir}/a/work"
    mkdir -p "${tmpdir}/b/upper" "${tmpdir}/b/work"
    mkfs.ext4 -F -d "${tmpdir}" -L "overlay" "${BINARIES_DIR}/overlay.ext4" 96M
    rm -rf "${tmpdir}"
}

function create_data() {
    local tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}"' RETURN

    mkdir -p "${tmpdir}/home/app/.ssh"
    mkdir -p "${tmpdir}/portable" "${tmpdir}/config"

    chown -R 1000:1000 "${tmpdir}/home/app"
    chmod 750 "${tmpdir}/home/app"
    chmod 700 "${tmpdir}/home/app/.ssh"

    mkfs.ext4 -F -d "${tmpdir}" -L "data" "${BINARIES_DIR}/data.ext4" 64M
}

function build_rauc_bundle() {
    local rauc_dir="${BR2_EXTERNAL_OFFLINELAB_PATH}/../.rauc"
    local bundle="${BINARIES_DIR}/offlinelab-update.raucb"
    local tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}"' RETURN

    if [ ! -f "${rauc_dir}/signing.key" ]; then
        echo "WARNING: RAUC signing key not found at ${rauc_dir}/signing.key — skipping bundle"
        return 0
    fi

    cp "${BINARIES_DIR}/kernel-a.img" "${tmpdir}/kernel.img"
    cp "${BINARIES_DIR}/rootfs.ext4" "${tmpdir}/rootfs.img"

    cat > "${tmpdir}/manifest.raucm" <<EOF
[update]
compatible=offlinelab-pi-zero-2w
version=$(date +%Y%m%d)

[bundle]
format=verity

[image.kernel]
filename=kernel.img

[image.rootfs]
filename=rootfs.img
EOF

    "${HOST_DIR}/bin/rauc" bundle \
        --cert="${rauc_dir}/signing.cert.pem" \
        --key="${rauc_dir}/signing.key" \
        "${tmpdir}" \
        "${bundle}"

    echo "RAUC bundle: ${bundle}"
}

function assemble() {
    local cfg="${BINARIES_DIR}/genimage.cfg"
    gen_config "${cfg}"

    trap 'rm -rf "${ROOTPATH_TMP}"' EXIT
    ROOTPATH_TMP="$(mktemp -d)"
    rm -rf "${GENIMAGE_TMP}"

    genimage \
        --rootpath "${ROOTPATH_TMP}" \
        --tmppath "${GENIMAGE_TMP}" \
        --inputpath "${BINARIES_DIR}" \
        --outputpath "${BINARIES_DIR}" \
        --config "${cfg}"
}

build_initramfs && sync
build_boot_scr && sync
build_kernel_squashfs && sync
create_overlay && sync
create_data && sync
assemble && sync
build_rauc_bundle && sync
exit $?
