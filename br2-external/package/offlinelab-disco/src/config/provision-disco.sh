#!/usr/bin/env bash
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
