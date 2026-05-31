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
set -e -u -o pipefail

declare TARGET_DIR="${TARGET_DIR:-}"

declare -a remove=(
    /etc/passwd- /etc/group- /etc/shadow- /etc/gshadow-
    /etc/subuid- /etc/subgid-
    /etc/systemd/system/multi-user.target.wants/wpa_supplicant.service
    /etc/systemd/system/dbus-fi.w1.wpa_supplicant1.service
    /var/lib/man-db/auto-update
)

printf 'uninitialized\n' >"${TARGET_DIR}/etc/machine-id"

for file in "${remove[@]}"; do
    rm -rf "${TARGET_DIR}${file}"
done

rm -rf "${TARGET_DIR}/var/run"
ln -sf ../run "${TARGET_DIR}/var/run"

mkdir -p "${TARGET_DIR}/data"
mkdir -p "${TARGET_DIR}/boot/firmware"

if [[ -f "${TARGET_DIR}/usr/lib/libnss_disco.so.2" ]]; then
    if [[ -f "${TARGET_DIR}/etc/nsswitch.conf" ]]; then
        sed -i 's/^hosts:.*/hosts: files disco dns/' "${TARGET_DIR}/etc/nsswitch.conf"
    fi
fi

# QEMU: configure eth0 (virtio-net) with DHCP via systemd-networkd
# pi-zero-2w is WiFi-only; no eth0 there. This file only matters on QEMU.
mkdir -p "${TARGET_DIR}/etc/systemd/network"
cat > "${TARGET_DIR}/etc/systemd/network/10-eth0.network" <<'EOF'
[Match]
Name=eth0

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
