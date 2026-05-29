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

KEY_DIR="/data/config/ssh/dropbear"
AUTH_KEYS="/data/home/app/.ssh/authorized_keys"
BOOT_AUTH_KEYS="/boot/firmware/config/authorized_keys"

mkdir -p "${KEY_DIR}"

if [[ ! -f "${KEY_DIR}/dropbear_ed25519_host_key" ]]; then
    dropbearkey -t ed25519 -f "${KEY_DIR}/dropbear_ed25519_host_key"
    echo "provision-ssh: generated ed25519 host key"
fi

if [[ ! -f "${AUTH_KEYS}" ]] && [[ -f "${BOOT_AUTH_KEYS}" ]]; then
    mkdir -p "$(dirname "${AUTH_KEYS}")"
    cp "${BOOT_AUTH_KEYS}" "${AUTH_KEYS}"
    chown 1000:1000 "${AUTH_KEYS}"
    chmod 600 "${AUTH_KEYS}"
    echo "provision-ssh: provisioned authorized_keys from ${BOOT_AUTH_KEYS}"
fi
