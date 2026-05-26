#!/usr/bin/env bash
set -e -u -o pipefail

BOOT_CONFIG="/boot/firmware/wpa_supplicant.conf"
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
