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

WIFI_CONFIG="/data/config/wifi/wpa_supplicant.conf"

if [[ ! -f "${WIFI_CONFIG}" ]]; then
    echo "wifi-setup: no config at ${WIFI_CONFIG}, exiting" >&2
    exit 0
fi

exec /usr/sbin/wpa_supplicant \
    -c "${WIFI_CONFIG}" \
    -i wlan0
