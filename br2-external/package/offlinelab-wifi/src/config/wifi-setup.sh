#!/usr/bin/env bash
set -e -u -o pipefail

WIFI_CONFIG="/data/config/wifi/wpa_supplicant.conf"

if [[ ! -f "${WIFI_CONFIG}" ]]; then
    echo "wifi-setup: no config at ${WIFI_CONFIG}, exiting" >&2
    exit 0
fi

exec /usr/sbin/wpa_supplicant \
    -c "${WIFI_CONFIG}" \
    -i wlan0
