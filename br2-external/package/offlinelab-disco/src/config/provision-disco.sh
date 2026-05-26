#!/usr/bin/env bash
set -e -u -o pipefail

BOOT_CONFIG="/boot/firmware/disco.yaml"
DATA_CONFIG="/data/config/disco/config.yaml"

mkdir -p /data/config/disco

if [[ -f "${DATA_CONFIG}" ]]; then
    echo "provision-disco: config already exists at ${DATA_CONFIG}"
    exit 0
fi

if [[ ! -f "${BOOT_CONFIG}" ]]; then
    echo "provision-disco: no config at ${BOOT_CONFIG}, using defaults"
    exit 0
fi

cp "${BOOT_CONFIG}" "${DATA_CONFIG}"
chmod 644 "${DATA_CONFIG}"
echo "provision-disco: provisioned from ${BOOT_CONFIG}"
