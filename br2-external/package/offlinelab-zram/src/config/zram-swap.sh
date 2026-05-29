#!/bin/sh
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

# shellcheck disable=SC1091
set -e

if [ "$(id -u || true)" -ne 0 ]; then
    echo "This script requires root."
    exit 1
fi

export PATH=/usr/sbin:/usr/bin:/sbin:/bin
unalias -a 2>/dev/null || true

[ "$#" -gt "0" ] && [ "$1" = "-x" ] && shift && set -x

zram_fraction="1/2"
zram_algorithm="lz4"
comp_factor=''
zram_fixedsize=''
zram_swap_debug=''

if [ -f /etc/default/zram-swap ]; then
    . /etc/default/zram-swap
fi

if [ -n "${zram_swap_debug}" ]; then
    set -x
fi

if [ -z "${comp_factor}" ]; then
    case "${zram_algorithm}" in
    lzo* | zstd) comp_factor="3" ;;
    lz4) comp_factor="2.5" ;;
    *) comp_factor="2" ;;
    esac
fi

regex_match() { echo "${1}" | grep -Eq -- "${2}" >/dev/null 2>&1; }

zram_swap_calc() {
    regex_match "${1}" '^[[:digit:]]+$' && { n="${1}" && shift; } || n=0
    LC_NUMERIC=C awk "BEGIN{printf \"%.${n}f\", ${*}}"
}

zram_swap_init() {
    if [ -n "${zram_fixedsize}" ]; then
        if ! regex_match "${zram_fixedsize}" '^[[:digit:]]+(\.[[:digit:]]+)?(G|M)$'; then
            echo "Error: Invalid size '${zram_fixedsize}'" >&2
            exit 1
        fi
        mem="${zram_fixedsize}"
    else
        totalmem="$(awk '/MemTotal/{print $2}' /proc/meminfo)"
        mem="$(zram_swap_calc "${totalmem} * ${comp_factor} * ${zram_fraction} * 1024")"
    fi

    device=''
    for i in $(seq 3); do
        sleep "$(zram_swap_calc 2 "0.1 * ${i}" || true)"
        device="$(zramctl -f -s "${mem}" -a "${zram_algorithm}")" || true
        [ -b "${device}" ] && break
    done

    if [ -b "${device}" ]; then
        trap 'zram_swap_remove_zdev ${device}' EXIT
        mkswap "${device}"
        swapon -d -p 15 "${device}"
        trap - EXIT
        return 0
    else
        echo "Error: Failed to initialize zram device" >&2
        return 1
    fi
}

zram_swap_end() {
    ret=0
    for dev in $(awk '/zram/ {print $1}' /proc/swaps || true); do
        swapoff "${dev}"
        if ! zram_swap_remove_zdev "${dev}"; then
            echo "Error: Failed to remove zram device ${dev}" >&2
            ret=1
        fi
    done
    return "${ret}"
}

zram_swap_remove_zdev() {
    if [ ! -b "${1}" ]; then
        echo "Error: No zram device '${1}' to remove" >&2
        return 1
    fi
    for i in $(seq 3); do
        sleep "$(zram_swap_calc 2 "0.1 * ${i}" || true)"
        zramctl -r "${1}" || true
        [ -b "${1}" ] || break
    done
    if [ -b "${1}" ]; then
        echo "Error: Couldn't remove zram device '${1}' after 3 attempts" >&2
        return 1
    fi
    return 0
}

main() {
    if ! modprobe zram; then
        echo "Error: Failed to load zram module" >&2
        return 1
    fi

    { [ "${#}" -eq "0" ] && set -- ""; } >/dev/null 2>&1

    case "${1}" in
    init | start)
        if grep -q zram /proc/swaps; then
            echo "Error: zram swap already in use" >&2
            return 1
        fi
        zram_swap_init
        ;;
    end | stop)
        if ! grep -q zram /proc/swaps; then
            echo "Error: no zram swaps to cleanup" >&2
            return 1
        fi
        zram_swap_end
        ;;
    *)
        echo "Usage: $(basename "${0}" || true) (start|stop)"
        exit 1
        ;;
    esac
}

main "${@}"
