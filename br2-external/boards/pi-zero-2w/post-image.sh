#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2155
set -e -o pipefail

export BUILD_DIR="${BUILD_DIR:-}"
export TARGET_DIR="${TARGET_DIR:-}"
export BINARIES_DIR="${BINARIES_DIR:-}"
export BR2_EXTERNAL_OFFLINELAB_PATH="${BR2_EXTERNAL_OFFLINELAB_PATH:-}"
export BOARD_DIR="$(dirname "${0}")"
export GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

function build_initramfs() {
    local tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}"' RETURN

    mkdir -p "${tmpdir}"/{bin,sbin,etc,proc,sys,dev,mnt,newroot,data,tmp}

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

function gen_config() {
    local output="${1}"
    local -a files=(
        Image
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

    for extra in wpa_supplicant.conf authorized_keys; do
        [[ -f "${BINARIES_DIR}/${extra}" ]] && files+=("${extra}")
    done

    local boot_files="$(printf '\\t\\t\\t"%s",\\n' "${files[@]}")"
    sed "s|#BOOT_FILES#|${boot_files}|" "${BOARD_DIR}/genimage.cfg.in" > "${output}"
}

function create_rootfs_b() {
    truncate -s 512M "${BINARIES_DIR}/rootfs-b.ext4"
    mkfs.ext4 -F -L "rootfs-b" "${BINARIES_DIR}/rootfs-b.ext4"
}

function create_data() {
    local tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}"' RETURN

    mkdir -p "${tmpdir}/home/app/.ssh"
    mkdir -p "${tmpdir}/overlay/upper" "${tmpdir}/overlay/work"
    mkdir -p "${tmpdir}/portable" "${tmpdir}/config"

    chown -R 1000:1000 "${tmpdir}/home/app"
    chmod 750 "${tmpdir}/home/app"
    chmod 700 "${tmpdir}/home/app/.ssh"

    mkfs.ext4 -F -d "${tmpdir}" -L "data" "${BINARIES_DIR}/data.ext4" 64M
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
create_rootfs_b && sync
create_data && sync
assemble && sync
exit $?
