#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2154,SC2312
# SC2154: BOARD_DIR, TARGET_DIR, BINARIES_DIR, COMMON_DIR, BOARD_IMAGE_NAME are set by post-image.sh
# SC2312: ls in subshell return value intentionally not checked
# Sourced by boards/scripts/post-build.sh and post-image.sh.
# BOARD_DIR  = boards/qemu/<arch>  (set by post-image.sh from POST_SCRIPT_ARGS)
# COMMON_DIR = boards/common       (set by post-image.sh)
# BOARD_COMPATIBLE, BOARD_IMAGE_NAME come from the board's meta file.

_FAMILY_DIR="$(dirname "${BOARD_DIR}")"
export BOOT_CMD_FILE="${_FAMILY_DIR}/uboot/boot.cmd"

function board_post_build() {
    # Configure virtio-net interface with DHCP via systemd-networkd.
    # Match by driver so dummy0 and sit0 are not picked up by this rule.
    mkdir -p "${TARGET_DIR}/etc/systemd/network"
    cat > "${TARGET_DIR}/etc/systemd/network/10-eth0.network" <<'EOF'
[Match]
Driver=virtio_net

[Network]
DHCP=yes
EOF

    # Patch RAUC config for virtio block device names (/dev/vda instead of /dev/mmcblk0p)
    if [[ -f "${TARGET_DIR}/etc/rauc/system.conf" ]]; then
        sed -i \
            -e 's|/dev/mmcblk0p|/dev/vda|g' \
            -e 's|compatible=offlinelab-pi-zero-2w|compatible=offlinelab-qemu-arm64|' \
            "${TARGET_DIR}/etc/rauc/system.conf"
    fi

    # Patch fw_env.config for virtio block bootstate partition
    if [[ -f "${TARGET_DIR}/etc/fw_env.config" ]]; then
        sed -i 's|/dev/mmcblk0p9|/dev/vda9|g' "${TARGET_DIR}/etc/fw_env.config"
    fi
}

function gen_config() {
    local output="${1}"
    # Boot partition for QEMU: boot.scr + initramfs only.
    # u-boot.bin is passed directly to QEMU via -bios, not stored on disk.
    local -a files=("boot.scr" "initramfs.cpio.gz")
    if [[ -f "${BINARIES_DIR}/bootconf.yaml.example" ]]; then
        files+=("bootconf.yaml.example")
    fi
    local boot_files
    boot_files="$(printf '\\t\\t\\t"%s",\\n' "${files[@]}")"
    sed \
        -e "s|#BOOT_FILES#|${boot_files}|" \
        -e "s|#IMAGE_NAME#|${BOARD_IMAGE_NAME}|" \
        "${COMMON_DIR}/genimage.cfg.in" > "${output}"
}
