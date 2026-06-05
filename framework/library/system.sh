#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

#
# Run a command as root.
# If already root: exec directly.
# If not: delegate to sudo boxctl-su, which enforces the /etc/boxctl/su.conf allowlist.
#
function priv::run() {
    log::trace "${FUNCNAME[0]}: Running privileged command: ${*}"

    [[ "${#}" -eq 0 ]] && return 2

    if [[ "${EUID}" -eq 0 ]]; then
        "${@}"
    else
        sudo boxctl-su "${@}"
    fi
}

#
# Keep sudo credentials alive in the background.
# Call once at the start of a long-running privileged script.
#
function system::sudo_keepalive() {
    log::trace "${FUNCNAME[0]}: Starting sudo keepalive background process"

    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
}

################################################################################
# EOF                                                                          #
################################################################################
