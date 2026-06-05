#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2154,SC2155,SC2312
# SC2154: BOARD_DIR, BINARIES_DIR, COMMON_DIR, BOARD_IMAGE_NAME are set by post-image.sh
# SC2312: ls in subshell return value intentionally not checked
# Sourced by boards/scripts/post-build.sh and post-image.sh.
# BOARD_DIR  = boards/rpi/<board>  (set by post-image.sh from POST_SCRIPT_ARGS)
# COMMON_DIR = boards/common       (set by post-image.sh)
# BOARD_COMPATIBLE, BOARD_IMAGE_NAME come from the board's meta file.

_FAMILY_DIR="$(dirname "${BOARD_DIR}")"
export BOOT_CMD_FILE="${_FAMILY_DIR}/uboot/boot.cmd"

function board_post_build() {
    :
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
        local file="${i#"${BINARIES_DIR}"/}"
        if printf '%s\n' "${files[@]}" | grep -q -- "^${file}$"; then continue; fi
        files+=("${file}")
    done

    if [[ -d "${BINARIES_DIR}/config" ]] && [[ -n "$(ls -A "${BINARIES_DIR}/config" 2>/dev/null)" ]]; then
        files+=("config")
    fi

    local boot_files
    boot_files="$(printf '\\t\\t\\t"%s",\\n' "${files[@]}")"
    sed \
        -e "s|#BOOT_FILES#|${boot_files}|" \
        -e "s|#IMAGE_NAME#|${BOARD_IMAGE_NAME}|" \
        "${COMMON_DIR}/genimage.cfg.in" > "${output}"
}
