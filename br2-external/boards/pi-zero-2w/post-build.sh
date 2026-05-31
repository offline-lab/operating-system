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

# Package installs can clobber /var/run symlink with a real directory
rm -rf "${TARGET_DIR}/var/run"
ln -sf ../run "${TARGET_DIR}/var/run"

mkdir -p "${TARGET_DIR}/data"
mkdir -p "${TARGET_DIR}/boot/firmware"

if [[ -f "${TARGET_DIR}/usr/lib/libnss_disco.so.2" ]]; then
    if [[ -f "${TARGET_DIR}/etc/nsswitch.conf" ]]; then
        sed -i 's/^hosts:.*/hosts: files disco dns/' "${TARGET_DIR}/etc/nsswitch.conf"
    fi
fi
