#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

################################################################################
# Time functions                                                               #
################################################################################

#
# Convert epoch to human readable
#

function time::human_readable_seconds() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 2

    log::trace "${FUNCNAME[0]}: Converting seconds to a human readable format"

    local T="${1}"
    local DAY="$((T / 60 / 60 / 24))" HR="$((T / 60 / 60 % 24))" MIN="$((T / 60 % 60))" SEC="$((T % 60))"

    [[ ${DAY} -gt 0 ]] && printf '%d days ' "${DAY}"
    [[ ${HR} -gt 0 ]] && printf '%d hours ' "${HR}"
    [[ ${MIN} -gt 0 ]] && printf '%d minute(s) ' "${MIN}"
    [[ ${DAY} -gt 0 || ${HR} -gt 0 || ${MIN} -gt 0 ]] && printf 'and '
    printf '%d seconds\n' "${SEC}"
}

#
# Return time in unixtime
#

function time::now() {
    local timezone="${1:-"Europe/Amsterdam"}"

    local now

    log::trace "${FUNCNAME[0]}: Retrieving unixtime in seconds"

    now="$(TZ="${timezone}" date -u +%s)" || return $?

    printf "%s" "${now}"
}

################################################################################
#                                                                              #
################################################################################
