#!/usr/bin/env bash
set -e -u -o pipefail

KEY_DIR="/data/config/ssh/dropbear"
AUTH_KEYS="/data/home/app/.ssh/authorized_keys"
BOOT_AUTH_KEYS="/boot/firmware/authorized_keys"

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
