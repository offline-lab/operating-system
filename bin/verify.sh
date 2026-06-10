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
# Verify a built Offline Lab OS image without hardware.
# Runs inside the builder container (needs fdisk, mount, e2fsprogs, cpio, file).
#
# Usage: bin/verify.sh [artifacts-dir]
#        Default artifacts-dir: /artifacts (inside container) or ./artifacts (host)
#
set -e -u -o pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

require_tools cpio find

declare -i PASS=0
declare -i FAIL=0
declare -i SKIP=0

################################################################################
# Test helpers
################################################################################

function pass() {
    PASS=$((PASS + 1))
    printf '  \e[1;32m✓\e[0m %s\n' "${*}"
}
function fail() {
    FAIL=$((FAIL + 1))
    printf '  \e[1;31m✗\e[0m %s\n' "${*}"
}
function skip() {
    SKIP=$((SKIP + 1))
    printf '  \e[1;33m-\e[0m %s (skipped)\n' "${*}"
}
function section() { printf '\n\e[1;97m=== %s ===\e[0m\n' "${*}"; }

function assert_file() {
    if [[ -f "${1}" ]]; then pass "${2:-${1} exists}"; else fail "${2:-${1} missing}"; fi
}

# shellcheck disable=SC2329
function assert_dir() {
    if [[ -d "${1}" ]]; then pass "${2:-${1} exists}"; else fail "${2:-${1} missing}"; fi
}

function assert_link() {
    if [[ -L "${1}" ]]; then pass "${2:-${1} is symlink}"; else fail "${2:-${1} not a symlink}"; fi
}

function assert_exec() {
    if [[ -x "${1}" ]]; then pass "${2:-${1} executable}"; else fail "${2:-${1} not executable}"; fi
}

function assert_contains() {
    local file="${1}" pattern="${2}" desc="${3:-}"
    if grep -q "${pattern}" "${file}" 2>/dev/null; then
        pass "${desc:-${file} contains ${pattern}}"
    else
        fail "${desc:-${file} missing ${pattern}}"
    fi
}

function assert_static() {
    local binary="${1}" desc="${2:-${1} is static}"
    local file_out
    file_out="$(file "${binary}" 2>/dev/null | cut -d: -f2-)" || true
    if [[ "${file_out}" == *"statically linked"* ]]; then
        pass "${desc}"
    else
        fail "${desc} — ${file_out}"
    fi
}

################################################################################
# Locate artifacts
################################################################################

ARTIFACTS="${1:-}"
if [[ -z "${ARTIFACTS}" ]]; then
    if [[ -d /artifacts ]]; then
        ARTIFACTS="/artifacts"
    elif [[ -d ./artifacts ]]; then
        ARTIFACTS="./artifacts"
    else
        echo "Usage: ${0} <artifacts-dir>"
        exit 1
    fi
fi

# Resolve the disk image: prefer offlinelab-*.img (buildbox), fall back to sdcard.img (Docker)
SDCARD=""
for _img in "${ARTIFACTS}"/offlinelab-*.img "${ARTIFACTS}/sdcard.img"; do
    if [[ -f "${_img}" ]]; then
        SDCARD="${_img}"
        break
    fi
done
ROOTFS="${ARTIFACTS}/rootfs.ext4"
INITRAMFS="${ARTIFACTS}/initramfs.cpio.gz"
KERNEL="${ARTIFACTS}/Image"
KERNEL_SQFS="${ARTIFACTS}/kernel-a.img"
UBOOT="${ARTIFACTS}/u-boot.bin"
BOOTSCR="${ARTIFACTS}/boot.scr"

# Board detection from artifacts path (e.g. artifacts/pi-zero-2w or artifacts/qemu-arm64)
BOARD="$(basename "${ARTIFACTS}")"
IS_RPI=0
[[ "${BOARD}" == *pi* || "${BOARD}" == *rpi* ]] && IS_RPI=1

# Board-specific RAUC partition layout
if [[ "${IS_RPI}" -eq 1 ]]; then
    _RAUC_COMPATIBLE="offlinelab-pi-zero-2w"
    _RAUC_KSLOT_A="mmcblk0p5"
    _RAUC_RSLOT_A="mmcblk0p6"
    _RAUC_KSLOT_B="mmcblk0p7"
    _RAUC_RSLOT_B="mmcblk0p8"
    _RAUC_BOOTSTATE="mmcblk0p9"
else
    _RAUC_COMPATIBLE="offlinelab-${BOARD}"
    _RAUC_KSLOT_A="vda5"
    _RAUC_RSLOT_A="vda6"
    _RAUC_KSLOT_B="vda7"
    _RAUC_RSLOT_B="vda8"
    _RAUC_BOOTSTATE="vda9"
fi

CLEANUP=()
# shellcheck disable=SC2329
function cleanup() {
    for dir in "${CLEANUP[@]}"; do
        sudo umount "${dir}" 2>/dev/null || true
        rmdir "${dir}" 2>/dev/null || true
    done
    if [[ -n "${LOOP_DEV:-}" ]]; then
        sudo losetup -d "${LOOP_DEV}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

################################################################################
# 1. Check raw artifacts exist
################################################################################

section "Artifact files"

assert_file "${ROOTFS}" "rootfs.ext4 exists"
assert_file "${INITRAMFS}" "initramfs.cpio.gz exists"
assert_file "${KERNEL}" "Kernel Image exists"
assert_file "${KERNEL_SQFS}" "kernel-a.img squashfs exists"
assert_file "${UBOOT}" "u-boot.bin exists"
assert_file "${BOOTSCR}" "boot.scr exists"

if [[ -n "${SDCARD}" ]]; then
    pass "disk image exists: $(basename "${SDCARD}")"
else
    # might be compressed only
    if compgen -G "${ARTIFACTS}/offlinelab-*.img.gz" >/dev/null 2>&1; then
        pass "compressed image exists"
    else
        fail "no disk image found (offlinelab-*.img or sdcard.img)"
    fi
fi

################################################################################
# 2. SD card partition layout
################################################################################

section "SD card partition layout"

if [[ -n "${SDCARD}" ]] && command -v fdisk &>/dev/null; then
    FDISK_OUT="$(fdisk -l "${SDCARD}" 2>/dev/null || true)"

    # MBR with extended partition: p1=boot p2=extended p3=overlay p4=data
    # Logical: p5=kernel-a p6=rootfs-a p7=kernel-b p8=rootfs-b p9=bootstate
    part_count="$(echo "${FDISK_OUT}" | grep -c "^${SDCARD}" || true)"
    if [[ "${part_count}" -ge 9 ]]; then
        pass "${part_count} partitions found (MBR extended layout)"
    else
        fail "Expected >=9 partitions (MBR extended), found ${part_count}"
    fi

    if echo "${FDISK_OUT}" | grep -q "${SDCARD}1.*FAT\|${SDCARD}1.*W95 FAT32\|${SDCARD}1.*0c"; then
        pass "Partition 1 is FAT (boot)"
    else
        fail "Partition 1 not FAT type"
    fi

    if echo "${FDISK_OUT}" | grep -q "${SDCARD}2.*Extended\|${SDCARD}2.*W95 Ext\|${SDCARD}2.*05\|${SDCARD}2.*0f"; then
        pass "Partition 2 is Extended container"
    else
        fail "Partition 2 not Extended type"
    fi

    for p in 3 4 5 6 7 8 9; do
        if echo "${FDISK_OUT}" | grep -q "${SDCARD}${p}.*Linux\|${SDCARD}${p}.*83"; then
            pass "Partition ${p} is Linux"
        else
            fail "Partition ${p} not Linux type"
        fi
    done

    if echo "${FDISK_OUT}" | grep "${SDCARD}1" | grep -q "\*"; then
        pass "Partition 1 is bootable"
    else
        fail "Partition 1 not marked bootable"
    fi
else
    skip "SD card partition check (no sdcard.img or fdisk)"
fi

################################################################################
# 3. Boot partition contents
################################################################################

section "Boot partition contents"

if [[ -n "${SDCARD}" ]] && command -v losetup &>/dev/null; then
    LOOP_DEV="$(sudo losetup --find --show --partscan "${SDCARD}" 2>/dev/null || true)"
    if [[ -n "${LOOP_DEV}" ]]; then
        BOOT_MNT="$(mktemp -d)"
        CLEANUP+=("${BOOT_MNT}")

        if sudo mount -o ro "${LOOP_DEV}p1" "${BOOT_MNT}" 2>/dev/null; then
            assert_file "${BOOT_MNT}/boot.scr" "boot.scr on boot partition"
            assert_file "${BOOT_MNT}/initramfs.cpio.gz" "initramfs.cpio.gz on boot partition"

            if [[ "${IS_RPI}" -eq 1 ]]; then
                assert_file "${BOOT_MNT}/u-boot.bin" "u-boot.bin on boot partition"
                assert_file "${BOOT_MNT}/config.txt" "config.txt on boot partition"
                assert_file "${BOOT_MNT}/cmdline.txt" "cmdline.txt on boot partition"

                if compgen -G "${BOOT_MNT}/*.dtb" >/dev/null 2>&1 \
                    || compgen -G "${BOOT_MNT}/bcm271*.dtb" >/dev/null 2>&1; then
                    pass "DTB files present"
                else
                    fail "No DTB files on boot partition"
                fi

                if [[ -f "${BOOT_MNT}/bootcode.bin" ]] \
                    || [[ -f "${BOOT_MNT}/rpi-firmware/bootcode.bin" ]]; then
                    pass "bootcode.bin present"
                else
                    if find "${BOOT_MNT}" -name "bootcode.bin" -print -quit 2>/dev/null | grep -q .; then
                        pass "bootcode.bin found"
                    else
                        fail "bootcode.bin missing from boot partition"
                    fi
                fi

                if [[ -f "${BOOT_MNT}/start.elf" ]]; then
                    pass "start.elf present"
                else
                    fail "start.elf missing"
                fi

                if [[ -f "${BOOT_MNT}/config.txt" ]]; then
                    assert_contains "${BOOT_MNT}/config.txt" "kernel=u-boot.bin" "config.txt loads u-boot.bin"
                    assert_contains "${BOOT_MNT}/config.txt" "arm_64bit=1" "config.txt sets arm_64bit=1"
                    assert_contains "${BOOT_MNT}/config.txt" "dwc2" "config.txt has dwc2 overlay"
                fi

                if [[ -f "${BOOT_MNT}/cmdline.txt" ]]; then
                    assert_contains "${BOOT_MNT}/cmdline.txt" "ttyS0" "cmdline.txt uses ttyS0 console"
                fi
            fi

            # boot.scr A/B logic (mkimage header + script text)
            if [[ -f "${BOOT_MNT}/boot.scr" ]]; then
                assert_contains "${BOOT_MNT}/boot.scr" "BOOT_ORDER" "boot.scr has BOOT_ORDER logic"
                assert_contains "${BOOT_MNT}/boot.scr" "BOOT_A_LEFT" "boot.scr has slot A counter"
                assert_contains "${BOOT_MNT}/boot.scr" "BOOT_B_LEFT" "boot.scr has slot B counter"
                assert_contains "${BOOT_MNT}/boot.scr" "rauc.slot=A" "boot.scr sets rauc.slot=A"
                assert_contains "${BOOT_MNT}/boot.scr" "rauc.slot=B" "boot.scr sets rauc.slot=B"
                assert_contains "${BOOT_MNT}/boot.scr" "storebootstate" "boot.scr saves state before boot"
            fi

            sudo umount "${BOOT_MNT}" 2>/dev/null || true
        else
            skip "Could not mount boot partition"
        fi
    else
        skip "Could not set up loop device (need root)"
    fi
else
    skip "Boot partition check (no sdcard.img or losetup)"
fi

################################################################################
# 4. Initramfs contents
################################################################################

section "Initramfs"

if [[ -f "${INITRAMFS}" ]]; then
    INITRAMFS_DIR="$(mktemp -d)"
    CLEANUP+=("${INITRAMFS_DIR}")

    if (cd "${INITRAMFS_DIR}" && gunzip -c "${INITRAMFS}" | cpio -id 2>/dev/null); then
        assert_file "${INITRAMFS_DIR}/init" "init script present"
        assert_exec "${INITRAMFS_DIR}/init" "init script executable"
        assert_file "${INITRAMFS_DIR}/bin/busybox" "busybox binary present"

        if [[ -f "${INITRAMFS_DIR}/bin/busybox" ]]; then
            assert_static "${INITRAMFS_DIR}/bin/busybox" "busybox is statically linked"
        fi

        for cmd in sh mount umount mkdir switch_root; do
            if [[ -L "${INITRAMFS_DIR}/bin/${cmd}" ]] || [[ -f "${INITRAMFS_DIR}/bin/${cmd}" ]]; then
                pass "initramfs has ${cmd}"
            else
                fail "initramfs missing ${cmd}"
            fi
        done

        for dir in proc sys dev mnt newroot data overlay; do
            assert_dir "${INITRAMFS_DIR}/${dir}" "initramfs has /${dir}"
        done

        if [[ -f "${INITRAMFS_DIR}/init" ]]; then
            assert_contains "${INITRAMFS_DIR}/init" "overlay" "init mounts overlayfs"
            assert_contains "${INITRAMFS_DIR}/init" "rauc.slot" "init parses rauc.slot from cmdline"
            assert_contains "${INITRAMFS_DIR}/init" "p6=rootfs-a" "init mounts rootfs-a (p6)"
            assert_contains "${INITRAMFS_DIR}/init" "p8=rootfs-b" "init mounts rootfs-b (p8)"
            assert_contains "${INITRAMFS_DIR}/init" "p3=overlay" "init mounts overlay partition (p3)"
            assert_contains "${INITRAMFS_DIR}/init" "p4=data" "init mounts data partition (p4)"
            assert_contains "${INITRAMFS_DIR}/init" "switch_root" "init calls switch_root"
        fi
    else
        fail "Could not extract initramfs"
    fi
else
    skip "Initramfs check (file not found)"
fi

################################################################################
# 5. Root filesystem
################################################################################

section "Root filesystem"

if [[ -f "${ROOTFS}" ]] && command -v mount &>/dev/null; then
    ROOTFS_MNT="$(mktemp -d)"
    CLEANUP+=("${ROOTFS_MNT}")

    if sudo mount -o ro,loop "${ROOTFS}" "${ROOTFS_MNT}" 2>/dev/null; then

        # Init system
        if [[ -f "${ROOTFS_MNT}/lib/systemd/systemd" ]] \
            || [[ -f "${ROOTFS_MNT}/usr/lib/systemd/systemd" ]]; then
            pass "systemd installed"
        else
            fail "systemd not found"
        fi

        assert_file "${ROOTFS_MNT}/usr/bin/bash" "bash installed"

        # Systemd units
        for unit in usb-gadget.service wifi-setup.service show-ip.service zram-swap.service \
            expand-data.service boot-firmware.mount boxctl-startup.service \
            dropbear.service boxctl-shutdown.service; do
            if [[ -f "${ROOTFS_MNT}/etc/systemd/system/${unit}" ]]; then
                pass "Unit ${unit} installed"
            else
                fail "Unit ${unit} missing"
            fi
        done

        # Multi-user wants
        for unit in wifi-setup.service show-ip.service zram-swap.service expand-data.service \
            boxctl-startup.service dropbear.service boxctl-shutdown.service; do
            if [[ -L "${ROOTFS_MNT}/etc/systemd/system/multi-user.target.wants/${unit}" ]]; then
                pass "Unit ${unit} enabled (wanted by multi-user)"
            else
                fail "Unit ${unit} not enabled"
            fi
        done

        # Sysinit wants
        for unit in usb-gadget.service; do
            if [[ -L "${ROOTFS_MNT}/etc/systemd/system/sysinit.target.wants/${unit}" ]]; then
                pass "Unit ${unit} enabled (wanted by sysinit)"
            else
                fail "Unit ${unit} not enabled in sysinit"
            fi
        done

        # Serial gettys
        for getty in serial-getty@ttyS0.service serial-getty@ttyGS0.service; do
            if [[ -L "${ROOTFS_MNT}/etc/systemd/system/getty.target.wants/${getty}" ]]; then
                pass "Getty ${getty} enabled"
            else
                fail "Getty ${getty} not enabled"
            fi
        done

        # Network configs
        for net in wlan0.network usb0.network; do
            assert_file "${ROOTFS_MNT}/etc/systemd/network/${net}" "Network config ${net} installed"
        done

        if [[ -f "${ROOTFS_MNT}/etc/systemd/network/usb0.network" ]]; then
            assert_contains "${ROOTFS_MNT}/etc/systemd/network/usb0.network" "DHCPServer" \
                "usb0.network has DHCPServer"
            assert_contains "${ROOTFS_MNT}/etc/systemd/network/usb0.network" "10.55.0.1" \
                "usb0.network has address 10.55.0.1"
        fi

        # Modules load
        if [[ -f "${ROOTFS_MNT}/etc/modules-load.d/99-offlinelab-usb-gadget.conf" ]]; then
            pass "modules-load.d/99-offlinelab-usb-gadget.conf installed"
            assert_contains "${ROOTFS_MNT}/etc/modules-load.d/99-offlinelab-usb-gadget.conf" "dwc2" \
                "usb-gadget modules-load has dwc2"
            assert_contains "${ROOTFS_MNT}/etc/modules-load.d/99-offlinelab-usb-gadget.conf" "configfs" \
                "usb-gadget modules-load has configfs"
        else
            fail "modules-load.d/99-offlinelab-usb-gadget.conf missing"
        fi

        if [[ -f "${ROOTFS_MNT}/etc/modules-load.d/99-offlinelab-zram.conf" ]]; then
            pass "modules-load.d/99-offlinelab-zram.conf installed"
            assert_contains "${ROOTFS_MNT}/etc/modules-load.d/99-offlinelab-zram.conf" "zram" \
                "zram modules-load has zram"
        else
            fail "modules-load.d/99-offlinelab-zram.conf missing"
        fi

        # Scripts
        for script in \
            init-usb-gadget init-wifi-setup init-show-ip init-zram-swap init-expand-data init-resources; do
            assert_exec "${ROOTFS_MNT}/usr/local/bin/${script}" "Script ${script} installed and executable"
        done

        # Dropbear
        if [[ -f "${ROOTFS_MNT}/usr/sbin/dropbear" ]]; then
            pass "dropbear installed"
        else
            fail "dropbear not found"
        fi

        # Service dependency checks
        if [[ -f "${ROOTFS_MNT}/etc/systemd/system/boot-firmware.mount" ]]; then
            assert_contains "${ROOTFS_MNT}/etc/systemd/system/boot-firmware.mount" \
                "LABEL=bootfs" "boot-firmware.mount uses label-based mount"
        fi
        if [[ -f "${ROOTFS_MNT}/etc/systemd/system/dropbear.service" ]]; then
            assert_contains "${ROOTFS_MNT}/etc/systemd/system/dropbear.service" \
                "Requires=boxctl-startup" "dropbear requires boxctl-startup (hard dep)"
        fi

        # Overlay files
        assert_file "${ROOTFS_MNT}/etc/fstab" "/etc/fstab present"
        if [[ -f "${ROOTFS_MNT}/etc/fstab" ]]; then
            assert_contains "${ROOTFS_MNT}/etc/fstab" "tmpfs" "fstab has tmpfs for /tmp"
        fi

        assert_file "${ROOTFS_MNT}/etc/hostname" "/etc/hostname present"
        if [[ -f "${ROOTFS_MNT}/etc/hostname" ]]; then
            assert_contains "${ROOTFS_MNT}/etc/hostname" "offlinelab" "hostname is offlinelab"
        fi

        assert_file "${ROOTFS_MNT}/etc/hosts" "/etc/hosts present"
        assert_file "${ROOTFS_MNT}/etc/modprobe.d/02w-wifi-fix.conf" "WiFi modprobe fix present"
        assert_file "${ROOTFS_MNT}/etc/sysctl.d/99-offlinelab.conf" "sysctl config present"
        assert_file "${ROOTFS_MNT}/etc/sudoers.d/admin" "sudoers.d/admin present"

        # User check
        if grep -q "^admin:" "${ROOTFS_MNT}/etc/passwd" 2>/dev/null; then
            pass "admin user exists in /etc/passwd"
            if grep "^admin:" "${ROOTFS_MNT}/etc/passwd" | grep -q "1000"; then
                pass "admin user has uid 1000"
            else
                fail "admin user does not have uid 1000"
            fi
        else
            fail "admin user missing from /etc/passwd"
        fi

        # Group check
        for grp in sudo bluetooth audio video; do
            if grep -q "^${grp}:" "${ROOTFS_MNT}/etc/group" 2>/dev/null; then
                pass "Group ${grp} exists"
            else
                fail "Group ${grp} missing"
            fi
        done

        # Merged usr
        if [[ -L "${ROOTFS_MNT}/bin" ]]; then
            pass "/bin is symlink (merged-usr)"
        else
            fail "/bin is not a symlink"
        fi

        # machine-id
        if [[ -f "${ROOTFS_MNT}/etc/machine-id" ]]; then
            content="$(cat "${ROOTFS_MNT}/etc/machine-id")"
            if [[ "${content}" == "uninitialized" ]]; then
                pass "machine-id is uninitialized (will be generated at boot)"
            else
                fail "machine-id is not 'uninitialized': ${content}"
            fi
        else
            skip "machine-id check"
        fi

        # /data mountpoint
        assert_dir "${ROOTFS_MNT}/data" "/data mountpoint exists"
        if sudo test -d "${ROOTFS_MNT}/boot/firmware"; then
            pass "/boot/firmware mountpoint exists"
        else
            fail "/boot/firmware mountpoint missing"
        fi

        # zram config
        assert_file "${ROOTFS_MNT}/etc/default/zram-swap" "zram-swap default config present"

        # /etc/issue
        if [[ -f "${ROOTFS_MNT}/etc/issue" ]]; then
            assert_contains "${ROOTFS_MNT}/etc/issue" "Offline Lab" "/etc/issue has branding"
        fi

        # modules.dep must not be empty (host-kmod needs XZ support)
        moddep="$(find "${ROOTFS_MNT}/lib/modules" -name modules.dep -print -quit 2>/dev/null || true)"
        if [[ -n "${moddep}" ]]; then
            if [[ -s "${moddep}" ]]; then
                pass "modules.dep is populated"
            else
                fail "modules.dep is EMPTY — host-kmod lacks XZ support (BR2_PACKAGE_HOST_KMOD_XZ=y)"
            fi
        else
            fail "modules.dep not found"
        fi

        # target kmod must have XZ support (modules are .ko.xz)
        if [[ -f "${ROOTFS_MNT}/usr/bin/kmod" ]]; then
            kmod_flags="$(strings "${ROOTFS_MNT}/usr/bin/kmod" 2>/dev/null | grep -o '[-+]XZ' | head -1)"
            if [[ "${kmod_flags}" == "+XZ" ]]; then
                pass "Target kmod has XZ support"
            else
                fail "Target kmod lacks XZ support (need BR2_PACKAGE_XZ=y) — modprobe can't load .ko.xz"
            fi
        fi

        # liblzma present (required by target kmod for .ko.xz)
        if find "${ROOTFS_MNT}" -name "liblzma.so*" -print -quit 2>/dev/null | grep -q .; then
            pass "liblzma present on target"
        else
            fail "liblzma missing — target kmod can't decompress .ko.xz modules"
        fi

        # netdev group
        if grep -q "^netdev:" "${ROOTFS_MNT}/etc/group" 2>/dev/null; then
            pass "Group netdev exists"
        else
            fail "Group netdev missing"
        fi

        # bash.bashrc for PS1
        assert_file "${ROOTFS_MNT}/etc/bash.bashrc" "bash.bashrc present"
        assert_file "${ROOTFS_MNT}/root/.bashrc" "root .bashrc present (sources bash.bashrc)"

        # /etc/profile has real PATH (not @PATH@ placeholder)
        if [[ -f "${ROOTFS_MNT}/etc/profile" ]]; then
            if grep -q '@PATH@' "${ROOTFS_MNT}/etc/profile"; then
                fail "/etc/profile has unsubstituted @PATH@ placeholder"
            else
                pass "/etc/profile has valid PATH"
            fi
        fi

        sudo umount "${ROOTFS_MNT}" 2>/dev/null || true
    else
        skip "Root filesystem mount (need root or loop device support)"
    fi
else
    skip "Root filesystem check (file not found or mount unavailable)"
fi

################################################################################
# 6. RAUC update system
################################################################################

section "RAUC update system"

if [[ -f "${ROOTFS}" ]] && command -v mount &>/dev/null; then
    RAUC_MNT="$(mktemp -d)"
    CLEANUP+=("${RAUC_MNT}")

    if sudo mount -o ro,loop "${ROOTFS}" "${RAUC_MNT}" 2>/dev/null; then

        assert_file "${RAUC_MNT}/etc/rauc/system.conf" "RAUC system.conf installed"
        assert_file "${RAUC_MNT}/etc/rauc/keyring.pem" "RAUC keyring installed"
        assert_file "${RAUC_MNT}/etc/fw_env.config" "fw_env.config installed"

        if [[ -f "${RAUC_MNT}/etc/rauc/system.conf" ]]; then
            assert_contains "${RAUC_MNT}/etc/rauc/system.conf" "bootloader=uboot" \
                "system.conf uses U-Boot backend"
            assert_contains "${RAUC_MNT}/etc/rauc/system.conf" "${_RAUC_COMPATIBLE}" \
                "system.conf has correct compatible"
            assert_contains "${RAUC_MNT}/etc/rauc/system.conf" "${_RAUC_KSLOT_A}" \
                "system.conf has kernel slot A"
            assert_contains "${RAUC_MNT}/etc/rauc/system.conf" "${_RAUC_RSLOT_A}" \
                "system.conf has rootfs slot A"
            assert_contains "${RAUC_MNT}/etc/rauc/system.conf" "${_RAUC_KSLOT_B}" \
                "system.conf has kernel slot B"
            assert_contains "${RAUC_MNT}/etc/rauc/system.conf" "${_RAUC_RSLOT_B}" \
                "system.conf has rootfs slot B"
            assert_contains "${RAUC_MNT}/etc/rauc/system.conf" "bootname=A" \
                "system.conf has bootname=A"
            assert_contains "${RAUC_MNT}/etc/rauc/system.conf" "bootname=B" \
                "system.conf has bootname=B"
        fi

        if [[ -f "${RAUC_MNT}/etc/fw_env.config" ]]; then
            assert_contains "${RAUC_MNT}/etc/fw_env.config" "${_RAUC_BOOTSTATE}" \
                "fw_env.config points at bootstate partition"
            assert_contains "${RAUC_MNT}/etc/fw_env.config" "0x4000" \
                "fw_env.config has correct env size (16KB)"
        fi

        if [[ -f "${RAUC_MNT}/usr/bin/rauc" ]]; then
            pass "rauc binary installed"
        else
            fail "rauc binary not found"
        fi

        if [[ -f "${RAUC_MNT}/usr/sbin/fw_printenv" ]]; then
            pass "fw_printenv installed"
        else
            fail "fw_printenv not found"
        fi

        assert_file "${RAUC_MNT}/etc/systemd/system/rauc-mark-good.service" \
            "rauc-mark-good.service installed"
        if [[ -L "${RAUC_MNT}/etc/systemd/system/multi-user.target.wants/rauc-mark-good.service" ]]; then
            pass "rauc-mark-good.service enabled (wanted by multi-user)"
        else
            fail "rauc-mark-good.service not enabled"
        fi

        # USB OTA update handler
        assert_exec "${RAUC_MNT}/usr/local/bin/init-usb-update" \
            "init-usb-update installed and executable"
        assert_file "${RAUC_MNT}/etc/systemd/system/usb-update@.service" \
            "usb-update@.service template installed"
        assert_file "${RAUC_MNT}/usr/lib/udev/rules.d/99-offlinelab-usb-update.rules" \
            "udev rule 99-offlinelab-usb-update.rules installed"

        if [[ -f "${RAUC_MNT}/usr/lib/udev/rules.d/99-offlinelab-usb-update.rules" ]]; then
            assert_contains \
                "${RAUC_MNT}/usr/lib/udev/rules.d/99-offlinelab-usb-update.rules" \
                "usb-update@" "udev rule triggers usb-update@ service"
            assert_contains \
                "${RAUC_MNT}/usr/lib/udev/rules.d/99-offlinelab-usb-update.rules" \
                'ID_BUS.*usb' "udev rule matches USB bus"
        fi

        if [[ -f "${RAUC_MNT}/etc/systemd/system/usb-update@.service" ]]; then
            assert_contains "${RAUC_MNT}/etc/systemd/system/usb-update@.service" \
                "BindsTo=dev-%i.device" "usb-update@ binds to device unit"
            assert_contains "${RAUC_MNT}/etc/systemd/system/usb-update@.service" \
                "init-usb-update" "usb-update@ calls init-usb-update"
        fi

        sudo umount "${RAUC_MNT}" 2>/dev/null || true
    else
        skip "RAUC check (could not mount rootfs)"
    fi
else
    skip "RAUC check (rootfs not found or mount unavailable)"
fi

# RAUC bundle artifact
RAUC_BUNDLE="${ARTIFACTS}/offlinelab-update.raucb"
if [[ -f "${RAUC_BUNDLE}" ]]; then
    pass "RAUC bundle artifact exists"
    bundle_size="$(stat -c%s "${RAUC_BUNDLE}" 2>/dev/null || stat -f%z "${RAUC_BUNDLE}" 2>/dev/null || echo 0)"
    if [[ "${bundle_size}" -gt 1048576 ]]; then
        pass "RAUC bundle size plausible ($((bundle_size / 1048576))MB)"
    else
        fail "RAUC bundle suspiciously small (${bundle_size} bytes)"
    fi
else
    skip "RAUC bundle check (not built — signing key may be missing)"
fi

################################################################################
# 7. Disco service discovery
################################################################################

section "Disco service discovery"

if [[ -f "${ROOTFS}" ]] && command -v mount &>/dev/null; then
    DISCO_MNT="$(mktemp -d)"
    CLEANUP+=("${DISCO_MNT}")

    if sudo mount -o ro,loop "${ROOTFS}" "${DISCO_MNT}" 2>/dev/null; then
        assert_file "${DISCO_MNT}/usr/bin/disco-daemon" "disco-daemon binary"
        assert_file "${DISCO_MNT}/usr/bin/disco" "disco CLI binary"
        assert_file "${DISCO_MNT}/usr/lib/libnss_disco.so.2" "libnss_disco.so.2 NSS module"
        assert_file "${DISCO_MNT}/etc/disco/config.yaml" "default config.yaml"
        assert_file "${DISCO_MNT}/etc/systemd/system/disco-daemon.service" "disco-daemon.service unit"
        assert_link "${DISCO_MNT}/etc/systemd/system/multi-user.target.wants/disco-daemon.service" "disco-daemon enabled"

        assert_contains "${DISCO_MNT}/etc/systemd/system/disco-daemon.service" "CAP_NET_RAW" "disco-daemon: CAP_NET_RAW"
        assert_contains "${DISCO_MNT}/etc/systemd/system/disco-daemon.service" "CAP_SYS_TIME" "disco-daemon: CAP_SYS_TIME"
        assert_contains "${DISCO_MNT}/etc/systemd/system/disco-daemon.service" "User=disco" "disco-daemon: runs as disco user"

        assert_file "${DISCO_MNT}/usr/bin/disco-gps-broadcaster" "disco-gps-broadcaster binary"
        assert_file "${DISCO_MNT}/etc/systemd/system/disco-gps-broadcaster.service" "disco-gps-broadcaster.service unit (not enabled)"

        assert_contains "${DISCO_MNT}/etc/nsswitch.conf" "disco" "nsswitch.conf includes disco"
        assert_contains "${DISCO_MNT}/etc/passwd" "disco" "disco user in passwd"

        sudo umount "${DISCO_MNT}" 2>/dev/null || true
    else
        skip "Disco checks (could not mount rootfs)"
    fi
else
    skip "Disco checks (rootfs not found)"
fi

################################################################################
# 8. Kernel config (if available in build output)
################################################################################

section "Kernel config"

KCONFIG=""
for f in "${ARTIFACTS}/../output/build/linux-custom/.config" \
    "${ARTIFACTS}/../../output/build/linux-custom/.config" \
    "/buildroot/output/build/linux-custom/.config" \
    "${HOME}/buildroot/output/build/linux-custom/.config" \
    "/home/builder/buildroot/output/build/linux-custom/.config"; do
    if [[ -f "${f}" ]]; then
        KCONFIG="${f}"
        break
    fi
done

if [[ -n "${KCONFIG}" ]]; then
    assert_contains "${KCONFIG}" "CONFIG_OVERLAY_FS=y" "Kernel: overlayfs enabled"
    assert_contains "${KCONFIG}" "CONFIG_BLK_DEV_INITRD=y" "Kernel: initramfs support"
    assert_contains "${KCONFIG}" "CONFIG_USB_DWC2=y\|CONFIG_USB_DWC2=m" "Kernel: USB DWC2 driver"
    assert_contains "${KCONFIG}" "CONFIG_USB_GADGET=y\|CONFIG_USB_GADGET=m" "Kernel: USB gadget support"
    assert_contains "${KCONFIG}" "CONFIG_USB_CONFIGFS=y\|CONFIG_USB_CONFIGFS=m" "Kernel: USB configfs"
    assert_contains "${KCONFIG}" "CONFIG_USB_CONFIGFS_ACM=y\|CONFIG_USB_CONFIGFS_ACM=m" "Kernel: USB ACM function"
    assert_contains "${KCONFIG}" "CONFIG_USB_CONFIGFS_ECM=y\|CONFIG_USB_CONFIGFS_ECM=m" "Kernel: USB ECM function"
    assert_contains "${KCONFIG}" "CONFIG_RD_GZIP=y" "Kernel: gzip initramfs decompression"
    assert_contains "${KCONFIG}" "CONFIG_MMC_BCM2835=y\|CONFIG_MMC_SDHCI_IPROC=y" "Kernel: MMC driver built-in"
    assert_contains "${KCONFIG}" "CONFIG_ZRAM=m\|CONFIG_ZRAM=y" "Kernel: zram support"
    assert_contains "${KCONFIG}" "CONFIG_USB_HID=y\|CONFIG_USB_HID=m" "Kernel: USB HID (keyboard) support"

    # Power-saving
    assert_contains "${KCONFIG}" "CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y" "Kernel: schedutil governor (power-saving)"
    assert_contains "${KCONFIG}" "CONFIG_ARM_PSCI_CPUIDLE=y" "Kernel: PSCI cpuidle (C-states)"
    assert_contains "${KCONFIG}" "CONFIG_SUSPEND=y" "Kernel: suspend-to-RAM support"
    assert_contains "${KCONFIG}" "CONFIG_NO_HZ_FULL=y" "Kernel: full tickless idle"
    assert_contains "${KCONFIG}" "CONFIG_HZ=100" "Kernel: HZ=100 (low timer rate)"

    # Security
    assert_contains "${KCONFIG}" "CONFIG_DM_VERITY=y\|CONFIG_DM_VERITY=m" "Kernel: dm-verity support"
    assert_contains "${KCONFIG}" "CONFIG_DM_VERITY_VERIFY_ROOTHASH_SIG=y" "Kernel: dm-verity root hash signature verification"
    assert_contains "${KCONFIG}" "CONFIG_SECURITY_APPARMOR=y" "Kernel: AppArmor LSM"
    assert_contains "${KCONFIG}" 'CONFIG_LSM="apparmor"' "Kernel: AppArmor in LSM list"
else
    skip "Kernel config (not found — only available inside build container)"
fi

################################################################################
# 9. Portable services & extensions
################################################################################

section "Portable services & extensions"

assert_file "${ARTIFACTS}/portable/hello-portable.raw" "hello-portable.raw built"

if [[ -f "${ROOTFS}" ]] && command -v mount &>/dev/null; then
    PORT_MNT="$(mktemp -d)"
    CLEANUP+=("${PORT_MNT}")

    if sudo mount -o ro,loop "${ROOTFS}" "${PORT_MNT}" 2>/dev/null; then

        # Binaries
        assert_file "${PORT_MNT}/usr/bin/portablectl" "portablectl binary"
        assert_file "${PORT_MNT}/usr/bin/systemd-sysext" "systemd-sysext binary"
        assert_file "${PORT_MNT}/usr/bin/systemd-confext" "systemd-confext binary"

        # Symlinks to /data
        if [[ -L "${PORT_MNT}/var/lib/portables" ]]; then
            target="$(readlink "${PORT_MNT}/var/lib/portables")"
            if [[ "${target}" == "/data/apps" ]]; then
                pass "/var/lib/portables → /data/apps"
            else
                fail "/var/lib/portables points to ${target}, expected /data/apps"
            fi
        else
            fail "/var/lib/portables is not a symlink"
        fi

        # sysext/confext mount points — plain dirs on rootfs; bind-mounted at runtime from /data
        if [[ -d "${PORT_MNT}/var/lib/extensions" ]] && [[ ! -L "${PORT_MNT}/var/lib/extensions" ]]; then
            pass "/var/lib/extensions exists as directory (sysext bind-mount target)"
        else
            fail "/var/lib/extensions missing or is a symlink (expected plain directory)"
        fi

        if [[ -d "${PORT_MNT}/etc/extensions" ]] && [[ ! -L "${PORT_MNT}/etc/extensions" ]]; then
            pass "/etc/extensions exists as directory (confext bind-mount target)"
        else
            fail "/etc/extensions missing or is a symlink (expected plain directory)"
        fi

        # sysext/confext bind-mount units installed and enabled
        assert_file "${PORT_MNT}/etc/systemd/system/var-lib-extensions.mount" \
            "var-lib-extensions.mount installed"
        assert_file "${PORT_MNT}/etc/systemd/system/etc-extensions.mount" \
            "etc-extensions.mount installed"
        assert_link "${PORT_MNT}/etc/systemd/system/sysinit.target.wants/var-lib-extensions.mount" \
            "var-lib-extensions.mount enabled"
        assert_link "${PORT_MNT}/etc/systemd/system/sysinit.target.wants/etc-extensions.mount" \
            "etc-extensions.mount enabled"

        # systemd-sysext and systemd-confext enabled at sysinit
        assert_link "${PORT_MNT}/etc/systemd/system/sysinit.target.wants/systemd-sysext.service" \
            "systemd-sysext.service enabled"
        assert_link "${PORT_MNT}/etc/systemd/system/sysinit.target.wants/systemd-confext.service" \
            "systemd-confext.service enabled"

        # modules-load.d
        if [[ -f "${PORT_MNT}/etc/modules-load.d/99-offlinelab-portable.conf" ]]; then
            pass "modules-load.d/99-offlinelab-portable.conf installed"
            assert_contains "${PORT_MNT}/etc/modules-load.d/99-offlinelab-portable.conf" "squashfs" \
                "portable modules-load has squashfs"
            assert_contains "${PORT_MNT}/etc/modules-load.d/99-offlinelab-portable.conf" "loop" \
                "portable modules-load has loop"
        else
            fail "modules-load.d/99-offlinelab-portable.conf missing"
        fi

        # portabled service unit
        if [[ -f "${PORT_MNT}/usr/lib/systemd/system/systemd-portabled.service" ]] \
            || [[ -f "${PORT_MNT}/lib/systemd/system/systemd-portabled.service" ]]; then
            pass "systemd-portabled.service unit exists"
        else
            fail "systemd-portabled.service unit missing"
        fi

        # AppArmor userspace
        assert_file "${PORT_MNT}/usr/sbin/apparmor_parser" "apparmor_parser binary"
        assert_file "${PORT_MNT}/usr/bin/aa-enabled" "aa-enabled binary"
        assert_file "${PORT_MNT}/usr/bin/aa-exec" "aa-exec binary"

        # Default portable profile
        assert_file "${PORT_MNT}/etc/portables/default.conf" "default portable profile"
        if [[ -f "${PORT_MNT}/etc/portables/default.conf" ]]; then
            assert_contains "${PORT_MNT}/etc/portables/default.conf" "ProtectSystem=strict" \
                "default profile: ProtectSystem=strict"
            assert_contains "${PORT_MNT}/etc/portables/default.conf" "NoNewPrivileges=yes" \
                "default profile: NoNewPrivileges=yes"
            assert_contains "${PORT_MNT}/etc/portables/default.conf" "MemoryMax=" \
                "default profile: MemoryMax limit"
        fi

        sudo umount "${PORT_MNT}" 2>/dev/null || true
    else
        skip "Portable services check (could not mount rootfs)"
    fi
else
    skip "Portable services check (rootfs not found)"
fi

################################################################################
# Summary
################################################################################

section "Summary"

TOTAL=$((PASS + FAIL + SKIP))
printf '\n  Total: %d  |  \e[1;32mPass: %d\e[0m  |  \e[1;31mFail: %d\e[0m  |  \e[1;33mSkip: %d\e[0m\n\n' \
    "${TOTAL}" "${PASS}" "${FAIL}" "${SKIP}"

if [[ "${FAIL}" -gt 0 ]]; then
    printf '  \e[1;31mVerification FAILED — %d check(s) did not pass.\e[0m\n\n' "${FAIL}"
    exit 1
fi

if [[ "${SKIP}" -gt "$((TOTAL / 2))" ]]; then
    printf '  \e[1;33mMany checks were skipped. Run inside the builder container as root for full coverage.\e[0m\n\n'
    exit 0
fi

printf '  \e[1;32mAll checks passed.\e[0m\n\n'
exit 0
