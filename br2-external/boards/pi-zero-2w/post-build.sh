#!/usr/bin/env bash
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
