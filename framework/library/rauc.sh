#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

# RAUC slot and bundle operations for boxctl.
# All functions require the framework to be sourced before this file.
# Requires: rauc (privileged — called via priv::run), jq

function rauc::status_json() {
    log::trace "${FUNCNAME[0]}: Getting RAUC status JSON"

    depends::check::silent rauc || return 1

    priv::run rauc status --output-format=json 2>/dev/null
}

function rauc::active_slot() {
    local status_json

    log::trace "${FUNCNAME[0]}: Getting active RAUC slot name"

    status_json="$(rauc::status_json)" || return 1

    jq -r '.booted' <<<"${status_json}"
}

function rauc::slots() {
    local status_json

    log::trace "${FUNCNAME[0]}: Listing all RAUC slot names"

    status_json="$(rauc::status_json)" || return 1

    jq -r '.slots | keys[]' <<<"${status_json}"
}

function rauc::slot_field() {
    local slot field status_json

    log::trace "${FUNCNAME[0]}: Getting field ${2} for slot ${1}"

    [[ "${#}" -ne 2 ]] && return 2

    slot="${1}"
    field="${2}"

    status_json="$(rauc::status_json)" || return 1

    jq -r \
        --arg slot "${slot}" \
        --arg field "${field}" \
        '.slots[$slot][$field] // "unknown"' <<<"${status_json}"
}

function rauc::slot_version() {
    local status_json slot

    log::trace "${FUNCNAME[0]}: Getting version for slot ${1}"

    [[ "${#}" -ne 1 ]] && return 2

    slot="${1}"

    status_json="$(rauc::status_json)" || return 1

    jq -r --arg slot "${slot}" \
        '.slots[$slot].bundle.version // "unknown"' <<<"${status_json}"
}

function rauc::slot_state() {
    local status_json slot

    log::trace "${FUNCNAME[0]}: Getting state for slot ${1}"

    [[ "${#}" -ne 1 ]] && return 2

    slot="${1}"

    status_json="$(rauc::status_json)" || return 1

    jq -r --arg slot "${slot}" \
        '.slots[$slot].state // "unknown"' <<<"${status_json}"
}

function rauc::slot_bootname() {
    log::trace "${FUNCNAME[0]}: Getting bootname for slot ${1}"

    [[ "${#}" -ne 1 ]] && return 2

    rauc::slot_field "${1}" bootname
}

function rauc::find_bundle() {
    local dir

    log::trace "${FUNCNAME[0]}: Searching for RAUC bundles in ${1:-/mnt}"

    dir="${1:-/mnt}"

    find "${dir}" -maxdepth 2 -name "*.raucb" 2>/dev/null | sort
}

function rauc::bundle_compatible() {
    local bundle

    log::trace "${FUNCNAME[0]}: Getting compatible string from bundle ${1}"

    [[ "${#}" -ne 1 ]] && return 2

    bundle="${1}"

    depends::check::silent rauc || return 1

    [[ ! -f "${bundle}" ]] && {
        log::error "${FUNCNAME[0]}: Bundle not found: ${bundle}"
        return 1
    }

    priv::run rauc info "${bundle}" 2>/dev/null | grep -E '^Compatible:' | awk '{print $2}'
}

function rauc::bundle_version() {
    local bundle

    log::trace "${FUNCNAME[0]}: Getting version from bundle ${1}"

    [[ "${#}" -ne 1 ]] && return 2

    bundle="${1}"

    depends::check::silent rauc || return 1

    [[ ! -f "${bundle}" ]] && {
        log::error "${FUNCNAME[0]}: Bundle not found: ${bundle}"
        return 1
    }

    priv::run rauc info "${bundle}" 2>/dev/null | grep -E '^Version:' | awk '{print $2}'
}

function rauc::install() {
    local bundle

    log::trace "${FUNCNAME[0]}: Installing RAUC bundle ${1}"

    [[ "${#}" -ne 1 ]] && return 2

    bundle="${1}"

    depends::check::silent rauc || return 1

    [[ ! -f "${bundle}" ]] && {
        log::error "${FUNCNAME[0]}: Bundle not found: ${bundle}"
        return 1
    }

    priv::run rauc install "${bundle}"
}

function rauc::inactive_slot() {
    local active

    log::trace "${FUNCNAME[0]}: Finding inactive rootfs slot"

    active="$(rauc::active_slot)" || return 1

    rauc::slots | grep -E '^rootfs\.' | grep -vx "${active}" | head -1
}

function rauc::mark_good() {
    log::trace "${FUNCNAME[0]}: Marking current boot slot as good"

    depends::check::silent rauc || return 1

    priv::run rauc mark good booted
}

function rauc::mark_active() {
    log::trace "${FUNCNAME[0]}: Marking slot ${1} as active for next boot"

    [[ "${#}" -ne 1 ]] && return 2

    depends::check::silent rauc || return 1

    priv::run rauc mark active "${1}"
}

function rauc::print_slots() {
    local status_json active

    log::trace "${FUNCNAME[0]}: Printing slot table"

    status_json="$(rauc::status_json)" || return 1

    active="$(jq -r '.booted' <<<"${status_json}")"

    printf '\n  %-14s %-5s %-10s %-10s %s\n' "SLOT" "BOOT" "STATE" "VERSION" "DEVICE"
    printf '  %-14s %-5s %-10s %-10s %s\n' "----" "----" "-----" "-------" "------"

    while IFS= read -r slot; do
        local bootname state version device marker

        bootname="$(jq -r --arg s "${slot}" '.slots[$s].bootname // "-"' <<<"${status_json}" || echo "-")"
        state="$(jq -r --arg s "${slot}" '.slots[$s].state // "unknown"' <<<"${status_json}" || echo "unknown")"
        version="$(jq -r --arg s "${slot}" '.slots[$s].bundle.version // "-"' <<<"${status_json}" || echo "-")"
        device="$(jq -r --arg s "${slot}" '.slots[$s].device // "-"' <<<"${status_json}" || echo "-")"
        marker=""

        [[ "${slot}" == "${active}" ]] && marker=" *"

        printf '  %-14s %-5s %-10s %-10s %s%s\n' \
            "${slot}" "${bootname}" "${state}" "${version}" "${device}" "${marker}"

    done < <(jq -r '.slots | keys[]' <<<"${status_json}")

    printf '\n  * active slot\n\n'
}
