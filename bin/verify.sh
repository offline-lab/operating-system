#!/usr/bin/env bash
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
    if file "${binary}" 2>/dev/null | grep -q "statically linked"; then
        pass "${desc}"
    else
        fail "${desc} — $(file "${binary}" 2>/dev/null | cut -d: -f2-)"
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

SDCARD="${ARTIFACTS}/sdcard.img"
ROOTFS="${ARTIFACTS}/rootfs.ext4"
INITRAMFS="${ARTIFACTS}/initramfs.cpio.gz"
KERNEL="${ARTIFACTS}/Image"
KERNEL_SQFS="${ARTIFACTS}/kernel-a.img"
UBOOT="${ARTIFACTS}/u-boot.bin"
BOOTSCR="${ARTIFACTS}/boot.scr"

CLEANUP=()
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

if [[ -f "${SDCARD}" ]]; then
    pass "sdcard.img exists"
else
    # might be compressed only
    if compgen -G "${ARTIFACTS}/offlinelab-sdcard-*.img.gz" >/dev/null 2>&1; then
        pass "sdcard compressed image exists"
        SDCARD=""
    else
        fail "no sdcard.img or compressed image found"
        SDCARD=""
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
            assert_file "${BOOT_MNT}/u-boot.bin" "u-boot.bin on boot partition"
            assert_file "${BOOT_MNT}/boot.scr" "boot.scr on boot partition"
            assert_file "${BOOT_MNT}/initramfs.cpio.gz" "initramfs.cpio.gz on boot partition"
            assert_file "${BOOT_MNT}/config.txt" "config.txt on boot partition"
            assert_file "${BOOT_MNT}/cmdline.txt" "cmdline.txt on boot partition"

            if compgen -G "${BOOT_MNT}/*.dtb" >/dev/null 2>&1 ||
                compgen -G "${BOOT_MNT}/bcm271*.dtb" >/dev/null 2>&1; then
                pass "DTB files present"
            else
                fail "No DTB files on boot partition"
            fi

            if [[ -f "${BOOT_MNT}/bootcode.bin" ]] ||
                [[ -f "${BOOT_MNT}/rpi-firmware/bootcode.bin" ]]; then
                pass "bootcode.bin present"
            else
                # check in root and subdirs
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
            assert_contains "${INITRAMFS_DIR}/init" "mmcblk0p6" "init mounts rootfs-a (p6)"
            assert_contains "${INITRAMFS_DIR}/init" "mmcblk0p8" "init mounts rootfs-b (p8)"
            assert_contains "${INITRAMFS_DIR}/init" "mmcblk0p3" "init mounts overlay partition (p3)"
            assert_contains "${INITRAMFS_DIR}/init" "mmcblk0p4" "init mounts data partition (p4)"
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
        if [[ -f "${ROOTFS_MNT}/lib/systemd/systemd" ]] ||
            [[ -f "${ROOTFS_MNT}/usr/lib/systemd/systemd" ]]; then
            pass "systemd installed"
        else
            fail "systemd not found"
        fi

        assert_file "${ROOTFS_MNT}/usr/bin/bash" "bash installed"

        # Systemd units
        for unit in usb-gadget.service wifi-setup.service zram-swap.service \
            expand-data.service boot-firmware.mount provision-wifi.service \
            provision-ssh.service dropbear.service fake-hwclock.service; do
            if [[ -f "${ROOTFS_MNT}/etc/systemd/system/${unit}" ]]; then
                pass "Unit ${unit} installed"
            else
                fail "Unit ${unit} missing"
            fi
        done

        # Multi-user wants
        for unit in wifi-setup.service zram-swap.service expand-data.service \
            provision-wifi.service provision-ssh.service dropbear.service; do
            if [[ -L "${ROOTFS_MNT}/etc/systemd/system/multi-user.target.wants/${unit}" ]]; then
                pass "Unit ${unit} enabled (wanted by multi-user)"
            else
                fail "Unit ${unit} not enabled"
            fi
        done

        # Sysinit wants
        for unit in usb-gadget.service fake-hwclock.service; do
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
        for script in usb-gadget.sh wifi-setup.sh zram-swap.sh expand-data.sh \
            provision-wifi.sh provision-ssh.sh fake-hwclock.sh; do
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
                "dev-mmcblk0p1.device" "boot-firmware.mount waits for device unit"
        fi
        if [[ -f "${ROOTFS_MNT}/etc/systemd/system/dropbear.service" ]]; then
            assert_contains "${ROOTFS_MNT}/etc/systemd/system/dropbear.service" \
                "Requires=provision-ssh" "dropbear requires provision-ssh (hard dep)"
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
        assert_file "${ROOTFS_MNT}/etc/sudoers.d/app" "sudoers.d/app present"

        # User check
        if grep -q "^app:" "${ROOTFS_MNT}/etc/passwd" 2>/dev/null; then
            pass "app user exists in /etc/passwd"
            if grep "^app:" "${ROOTFS_MNT}/etc/passwd" | grep -q "1000"; then
                pass "app user has uid 1000"
            else
                fail "app user does not have uid 1000"
            fi
        else
            fail "app user missing from /etc/passwd"
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
# 6. Kernel config (if available in build output)
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
else
    skip "Kernel config (not found — only available inside build container)"
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
