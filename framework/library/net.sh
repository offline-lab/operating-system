#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

################################################################################
# Network and Internet related helpers                                         #
################################################################################

# REQUIRES INTERNET
# Fetches the public IP of the local connection via curl.
function net::get_ip() {
    log::trace "${FUNCNAME[0]}: Get the IP address of the local connection"

    depends::check::silent curl || return 1

    curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null
}

################################################################################
# Validation — no network required                                             #
################################################################################

function net::is_ip4() {
    local ip="${1}"

    log::trace "${FUNCNAME[0]}: Checking if ${ip} is a valid ipv4 address"

    local stat=1

    if [[ "${ip}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local OIFS="${IFS}"
        IFS='.'
        # shellcheck disable=SC2206
        local -a segments=(${ip})
        IFS="${OIFS}"

        [[ "${segments[0]}" -le 255 ]] &&
            [[ "${segments[1]}" -le 255 ]] &&
            [[ "${segments[2]}" -le 255 ]] &&
            [[ "${segments[3]}" -le 255 ]]

        stat="${?}"
    fi

    return "${stat}"
}

function net::is_ip6() {
    local ip="${1}"

    log::trace "${FUNCNAME[0]}: Checking if ${ip} is a valid ipv6 address"

    # busybox grep -E handles this pattern without PCRE
    echo "${ip}" |
        grep -Eq '^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:(:[0-9a-fA-F]{1,4}){1,6}|:(:[0-9a-fA-F]{1,4}){1,7}|::)$'
}

function net::is_fqdn() {
    local name="${1}"
    local len="${#name}"

    log::trace "${FUNCNAME[0]}: Checking if ${name} is a valid FQDN"

    # Length check replaces the PCRE lookahead (?=^.{4,255}$)
    [[ "${len}" -lt 4 || "${len}" -gt 255 ]] && return 1

    # Labels must not start or end with hyphens; TLD must be alpha only
    echo "${name}" |
        grep -Eq '^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}\.?$'
}

function net::is_email() {
    local address="${1}"

    log::trace "${FUNCNAME[0]}: Checking if ${address} is a valid email address"

    local regex="^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"

    [[ "${address}" =~ ${regex} ]]
}

################################################################################
# HTTP timing — REQUIRES INTERNET                                              #
################################################################################

# REQUIRES INTERNET
function net::http::time() {
    log::trace "${FUNCNAME[0]}: Get timing for a http request"

    depends::check::silent curl || return 1

    local w_string
    w_string="$(
        printf "dns:          %s\nconnect:      %s\npretransfer:  %s\nstarttransfer:%s\ntotal:        %s\n" \
            "%{time_namelookup}" \
            "%{time_connect}" \
            "%{time_pretransfer}" \
            "%{time_starttransfer}" \
            "%{time_total}\n"
    )"

    curl -qs "${@}" -o /dev/null -w "${w_string}"
}

################################################################################
# EOF                                                                          #
################################################################################
