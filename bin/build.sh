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

# vi: ft=bash
# shellcheck shell=bash
#
# Build script — runs inside the Docker container.
# Invoked by builder.sh or manually inside the container.
#
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

require_tools nproc mountpoint blkid mkfs.ext4 mount ccache make pigz date cp

NPROC="$(nproc)"
export MAKEFLAGS="-j${NPROC}"

log "Starting build with ${NPROC} CPUs"

if [[ -f /buildroot/output.img ]]; then
    if ! mountpoint -q /buildroot/output 2>/dev/null; then
        mkdir -p /buildroot/output
        if ! blkid /buildroot/output.img &>/dev/null; then
            log "Formatting output disk image"
            mkfs.ext4 -F -q /buildroot/output.img
        fi
        mount -o loop /buildroot/output.img /buildroot/output
    fi
fi

if [[ ! -d /buildroot/.ccache ]]; then
    mkdir -p /buildroot/.ccache
    chmod 0775 /buildroot/.ccache
    chown -R builder:builder /buildroot/.ccache
    ccache --max-size=15G
fi

if sudo mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null; then
    log_dim "Mounted binfmt_misc"
else
    log_dim "binfmt_misc already mounted or unavailable"
fi

log "Loading defconfig"
make -C /buildroot BR2_EXTERNAL=/work/br2-external offlinelab_pi_zero_2w_defconfig

if [[ -f /work/.config ]]; then
    log "Merging custom .config"
    /buildroot/support/kconfig/merge_config.sh \
        -m -r -O /buildroot \
        /buildroot/.config /work/.config
fi

log "Running olddefconfig"
make -C /buildroot BR2_EXTERNAL=/work/br2-external olddefconfig

log "Building (this takes a while)..."
make -C /buildroot BR2_EXTERNAL=/work/br2-external BR2_JLEVEL="${NPROC}" -j"${NPROC}"

timestamp="$(date +%Y-%m-%d-%H%M%S)"

for img in /buildroot/output/images/offlinelab-*.img; do
    [[ -f "${img}" ]] || continue
    log "Compressing $(basename "${img}")"
    base="$(basename "${img}" .img)"
    pigz --force -9 "${img}" --stdout >"/artifacts/${base}-${timestamp}.img.gz"
done

log "Copying artifacts"
cp -rv /buildroot/output/images/* /artifacts/

log "Build complete"
