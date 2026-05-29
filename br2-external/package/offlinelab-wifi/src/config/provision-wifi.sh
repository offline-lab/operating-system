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

set -e -u -o pipefail

BOOT_CONFIG="/boot/firmware/config/wpa_supplicant.conf"
DATA_CONFIG="/data/config/wifi/wpa_supplicant.conf"

mkdir -p /data/config/wifi

if [[ -f "${DATA_CONFIG}" ]]; then
    echo "provision-wifi: config already exists at ${DATA_CONFIG}"
    exit 0
fi

if [[ ! -f "${BOOT_CONFIG}" ]]; then
    echo "provision-wifi: no config at ${BOOT_CONFIG}, skipping"
    exit 0
fi

cp "${BOOT_CONFIG}" "${DATA_CONFIG}"
chmod 600 "${DATA_CONFIG}"
echo "provision-wifi: provisioned from ${BOOT_CONFIG}"
