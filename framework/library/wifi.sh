#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

# WiFi management via wpa_cli for boxctl.
# All functions require the framework to be sourced before this file.
# Requires: wpa_cli (privileged — called via priv::run), ip

WIFI_INTERFACE="${WIFI_INTERFACE:-wlan0}"

function wifi::cli() {
    log::trace "${FUNCNAME[0]}: wpa_cli ${*}"

    depends::check::silent wpa_cli || return 1

    priv::run wpa_cli -i "${WIFI_INTERFACE}" "${@}" 2>/dev/null
}

function wifi::state() {
    log::trace "${FUNCNAME[0]}: Getting wpa_supplicant state"

    wifi::cli status 2>/dev/null | grep -E '^wpa_state=' | cut -d= -f2
}

function wifi::is_connected() {
    log::trace "${FUNCNAME[0]}: Checking if WiFi is connected"

    [[ "$(wifi::state)" == "COMPLETED" ]]
}

function wifi::current_ssid() {
    log::trace "${FUNCNAME[0]}: Getting current SSID"

    wifi::cli status 2>/dev/null | grep -E '^ssid=' | cut -d= -f2
}

function wifi::current_ip() {
    log::trace "${FUNCNAME[0]}: Getting current IP on ${WIFI_INTERFACE}"

    ip -4 addr show dev "${WIFI_INTERFACE}" 2>/dev/null |
        grep -oE 'inet [0-9.]+' |
        awk '{print $2}'
}

function wifi::scan() {
    log::trace "${FUNCNAME[0]}: Triggering WiFi scan"

    wifi::cli scan >/dev/null || return 1
    sleep 3
    wifi::cli scan_results 2>/dev/null
}

function wifi::list_networks() {
    log::trace "${FUNCNAME[0]}: Listing configured networks"

    wifi::cli list_networks 2>/dev/null
}

function wifi::connect() {
    local netid ssid psk

    log::trace "${FUNCNAME[0]}: Connecting to ${1}"

    [[ "${#}" -lt 2 ]] && return 2

    ssid="${1}"
    psk="${2}"

    netid="$(wifi::cli add_network)" || {
        log::error "${FUNCNAME[0]}: Failed to add network"
        return 1
    }

    [[ ! "${netid}" =~ ^[0-9]+$ ]] && {
        log::error "${FUNCNAME[0]}: Unexpected network id: ${netid}"
        return 1
    }

    wifi::cli set_network "${netid}" ssid "\"${ssid}\"" >/dev/null || return 1
    wifi::cli set_network "${netid}" psk "\"${psk}\"" >/dev/null || return 1
    wifi::cli enable_network "${netid}" >/dev/null || return 1
    wifi::cli save_config >/dev/null || return 1
    wifi::cli reassociate >/dev/null || return 1

    log::info "${FUNCNAME[0]}: Connecting to ${ssid}..."
}

function wifi::status() {
    wifi::print_status
}

function wifi::print_status() {
    local state ssid ip

    log::trace "${FUNCNAME[0]}: Printing WiFi status"

    state="$(wifi::state)"
    ssid="$(wifi::current_ssid)"
    ip="$(wifi::current_ip)"

    printf '\n  Interface : %s\n' "${WIFI_INTERFACE}"
    printf '  State     : %s\n' "${state}"
    printf '  SSID      : %s\n' "${ssid:--}"
    printf '  IP        : %s\n\n' "${ip:--}"
}

function wifi::print_scan() {
    local results

    log::trace "${FUNCNAME[0]}: Printing scan results"

    log::info "${FUNCNAME[0]}: scanning for networks"

    results="$(wifi::scan)" || return 1

    printf '\n  %-32s %-7s %-8s %s\n' "SSID" "SIGNAL" "FREQ" "FLAGS"
    printf '  %-32s %-7s %-8s %s\n' "----" "------" "----" "-----"

    # wpa_cli scan_results: bssid / frequency / signal level / flags / ssid
    while IFS=$'\t' read -r bssid freq signal flags ssid; do

        [[ "${bssid}" == "bssid" ]] && continue
        printf '  %-32s %-7s %-8s %s\n' "${ssid}" "${signal}" "${freq}" "${flags}"

    done <<<"${results}"

    printf '\n'
}
