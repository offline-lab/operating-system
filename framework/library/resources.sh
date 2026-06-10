#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

# Host resource measurement and baseline read/write.
# Written at boot by offlinelab-resources.service via resources::snapshot.

_RESOURCES_FILE="${_RESOURCES_FILE:-/data/config/resources.json}"
_PROC_MEMINFO="${_PROC_MEMINFO:-/proc/meminfo}"
_CPU_ONLINE_PATH="${_CPU_ONLINE_PATH:-/sys/devices/system/cpu/online}"
_STORAGE_PATH="${_STORAGE_PATH:-/data}"

################################################################################
# Measurement — live reads from /proc and /sys                                 #
################################################################################

function resources::cpu_cores() {
    log::trace "${FUNCNAME[0]}: reading CPU count"
    local online
    online="$(cat "${_CPU_ONLINE_PATH}" 2>/dev/null || echo "0")"
    # Format: "0-3" = 4 cores, "0" = 1 core
    awk -F- '{if (NF==2) print $2-$1+1; else print 1}' <<<"${online}"
}

function resources::total_memory_mb() {
    log::trace "${FUNCNAME[0]}: reading total memory"
    awk '/^MemTotal:/ {print int($2 / 1024)}' "${_PROC_MEMINFO}"
}

function resources::used_memory_mb() {
    log::trace "${FUNCNAME[0]}: reading used memory"
    awk '/^MemTotal:/ {total=$2} /^MemAvailable:/ {avail=$2} END {print int((total-avail)/1024)}' \
        "${_PROC_MEMINFO}"
}

function resources::total_storage_mb() {
    log::trace "${FUNCNAME[0]}: reading ${_STORAGE_PATH} total size"
    depends::check::silent df || return 1
    df -m "${_STORAGE_PATH}" 2>/dev/null | awk 'NR==2 {print $2}'
}

################################################################################
# Write — snapshot measurements to JSON                                        #
################################################################################

function resources::snapshot() {
    log::trace "${FUNCNAME[0]}: writing resource snapshot to ${_RESOURCES_FILE}"

    depends::check::silent jq || return 1

    local cpu_cores total_memory_mb total_storage_mb used_memory_mb measured_at
    cpu_cores="$(resources::cpu_cores)"
    total_memory_mb="$(resources::total_memory_mb)"
    total_storage_mb="$(resources::total_storage_mb)"
    used_memory_mb="$(resources::used_memory_mb)"
    measured_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    mkdir -p "$(dirname "${_RESOURCES_FILE}")"

    jq -n \
        --argjson total_memory_mb "${total_memory_mb}" \
        --argjson total_storage_mb "${total_storage_mb}" \
        --argjson cpu_cores "${cpu_cores}" \
        --argjson baseline_memory_mb "${used_memory_mb}" \
        --arg measured_at "${measured_at}" \
        '{
            total_memory_mb: $total_memory_mb,
            total_storage_mb: $total_storage_mb,
            cpu_cores: $cpu_cores,
            baseline_memory_mb: $baseline_memory_mb,
            measured_at: $measured_at
        }' >"${_RESOURCES_FILE}"

    log::info "${FUNCNAME[0]}: ram=${total_memory_mb}MB cpu=${cpu_cores} storage=${total_storage_mb}MB used=${used_memory_mb}MB"
}

################################################################################
# Read — query the JSON snapshot                                                #
################################################################################

function resources::get() {
    log::trace "${FUNCNAME[0]}: reading key from resources.json"

    [[ "${#}" -ne 1 ]] && return 2

    local key="${1}"
    shift

    depends::check::silent jq || return 1
    fs::is_file "${_RESOURCES_FILE}" || return 1

    jq -r --arg key "${key}" '.[$key] // empty' "${_RESOURCES_FILE}"
}

function resources::available_memory() {
    log::trace "${FUNCNAME[0]}: calculating available memory"

    depends::check::silent jq || return 1
    fs::is_file "${_RESOURCES_FILE}" || return 1

    jq -r '.total_memory_mb - .baseline_memory_mb' "${_RESOURCES_FILE}"
}

function resources::available_storage() {
    log::trace "${FUNCNAME[0]}: reading available ${_STORAGE_PATH} storage"

    depends::check::silent df || return 1

    df -m "${_STORAGE_PATH}" 2>/dev/null | awk 'NR==2 {print $4}'
}
