#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

# Read host resource baseline from /data/config/resources.json.
# Written at boot by offlinelab-resources.service (init-resources).

_RESOURCES_FILE="${_RESOURCES_FILE:-/data/config/resources.json}"

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
    log::trace "${FUNCNAME[0]}: reading available /data storage"

    depends::check::silent df || return 1

    df -m /data 2>/dev/null | awk 'NR==2 {print $4}'
}
