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

BOOT_CONFIG="/boot/firmware/config/disco.yaml"
DATA_CONFIG="/data/config/disco/config.yaml"
DEFAULT_CONFIG="/etc/disco/config.yaml"

mkdir -p /data/config/disco

if [[ -f "${DATA_CONFIG}" ]]; then
    exit 0
fi

if [[ -f "${BOOT_CONFIG}" ]]; then
    cp "${BOOT_CONFIG}" "${DATA_CONFIG}"
    echo "provision-disco: provisioned from ${BOOT_CONFIG}"
elif [[ -f "${DEFAULT_CONFIG}" ]]; then
    cp "${DEFAULT_CONFIG}" "${DATA_CONFIG}"
    echo "provision-disco: provisioned from defaults"
fi

chmod 644 "${DATA_CONFIG}" 2>/dev/null || true
