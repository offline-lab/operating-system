#!/usr/bin/env bash
set -e -u -o pipefail

DISK="/dev/mmcblk0"
PART_NUM=4
PART="${DISK}p${PART_NUM}"

if [[ ! -b "${PART}" ]]; then
    echo "expand-data: ${PART} not found, skipping" >&2
    exit 0
fi

# Ensure data directories exist (idempotent, runs every boot)
# Overlay dirs are on the dedicated overlay partition (p3), not here
mkdir -p /data/home/app/.ssh
mkdir -p /data/portable /data/config

if [[ ! -f /data/home/app/.bashrc ]]; then
    printf '[ -f /etc/bash.bashrc ] && . /etc/bash.bashrc\n' > /data/home/app/.bashrc
fi

chown -R 1000:1000 /data/home/app
chmod 750 /data/home/app
chmod 700 /data/home/app/.ssh

# Check if partition needs expansion
current_end="$(sfdisk -l "${DISK}" 2>/dev/null | awk -v p="${PART}" '$1 == p {print $3}')"
disk_end="$(sfdisk -l "${DISK}" 2>/dev/null | awk '/^Disk.*sectors/ {print $7}')"

if [[ -z "${current_end}" ]] || [[ -z "${disk_end}" ]]; then
    echo "expand-data: could not determine partition layout" >&2
    exit 0
fi

margin=$((disk_end - current_end))
if [[ "${margin}" -lt 2048 ]]; then
    echo "expand-data: partition already at full size"
    exit 0
fi

echo "expand-data: expanding partition ${PART_NUM} on ${DISK}"
echo ",+" | sfdisk -N "${PART_NUM}" "${DISK}" --no-reread || true
partprobe "${DISK}" || true
sleep 1
resize2fs "${PART}"

echo "expand-data: done"
