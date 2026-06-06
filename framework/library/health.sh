#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

# Device system status helpers for boxctl.
# All functions require the framework to be sourced before this file.
# Requires: systemctl, df, free, cat (/sys/kernel/security/apparmor/profiles)

function health::failed_units() {
    log::trace "${FUNCNAME[0]}: Getting failed systemd units"

    depends::check::silent systemctl || return 1

    systemctl list-units \
        --state=failed \
        --no-legend \
        --no-pager 2>/dev/null |
        awk '{print $1}'
}

function health::failed_unit_count() {
    log::trace "${FUNCNAME[0]}: Counting failed systemd units"

    health::failed_units | wc -l | tr -d ' '
}

function health::apparmor_status() {
    log::trace "${FUNCNAME[0]}: Getting AppArmor status"

    if [[ -f /sys/kernel/security/apparmor/profiles ]]; then
        local enforced loaded

        enforced="$(grep -c ' (enforce)$' /sys/kernel/security/apparmor/profiles 2>/dev/null || echo 0)"
        loaded="$(wc -l </sys/kernel/security/apparmor/profiles 2>/dev/null || echo 0)"

        echo "${enforced}/${loaded} profiles enforced"
    else
        echo "unavailable"
    fi
}

function health::verity_status() {
    log::trace "${FUNCNAME[0]}: Getting dm-verity status"

    if [[ -d /sys/block ]]; then
        # dm-verity devices appear as dm-X with verity target
        local count

        count="$(
            find /sys/block -name 'dm-*' -maxdepth 1 2>/dev/null |
                while read -r dev; do
                    target="${dev}/dm/target_types"
                    [[ -f "${target}" ]] && grep -q verity "${target}" 2>/dev/null && echo ok
                done | wc -l
        )"

        if [[ "${count:-0}" -gt 0 ]]; then
            echo "${count} device(s) verified"
        else
            echo "no verity devices"
        fi
    else
        echo "unknown"
    fi
}

function health::disk_usage() {
    local mount

    log::trace "${FUNCNAME[0]}: Getting disk usage for ${1:-/data}"

    mount="${1:-/data}"

    df -h "${mount}" 2>/dev/null | awk 'NR==2 {printf "%s used of %s (%s)", $3, $2, $5}'
}

function health::memory_usage() {
    log::trace "${FUNCNAME[0]}: Getting memory usage"

    free -h 2>/dev/null | awk '/^Mem:/ {printf "%s used of %s", $3, $2}'
}

function health::print_health() {
    local failed apparmor verity disk mem

    log::trace "${FUNCNAME[0]}: Printing system health summary"

    failed="$(health::failed_unit_count)"
    apparmor="$(health::apparmor_status)"
    verity="$(health::verity_status)"
    disk="$(health::disk_usage /data)"
    mem="$(health::memory_usage)"

    printf '\n  %-18s %s\n' "Failed units:" "${failed}"
    printf '  %-18s %s\n' "AppArmor:" "${apparmor}"
    printf '  %-18s %s\n' "dm-verity:" "${verity}"
    printf '  %-18s %s\n' "Disk (/data):" "${disk}"
    printf '  %-18s %s\n\n' "Memory:" "${mem}"

    if [[ "${failed:-0}" -gt 0 ]]; then
        printf '  Failed units:\n'

        health::failed_units | while read -r unit; do
            printf '    - %s\n' "${unit}"
        done

        printf '\n'
    fi
}
