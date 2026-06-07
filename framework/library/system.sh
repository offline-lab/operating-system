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
# machine-id persistence                                                       #
################################################################################

MACHINE_ID_DEST="${MACHINE_ID_DEST:-/data/config/system/machine-id}"
MACHINE_ID_SRC="${MACHINE_ID_SRC:-/etc/machine-id}"

#
# Persist /etc/machine-id to /data so it survives overlay resets.
# No-ops if already persisted, not yet initialized, or source is missing.
#
function machine_id::persist() {
    log::trace "${FUNCNAME[0]}: persisting machine-id to ${MACHINE_ID_DEST}"

    if [[ -f "${MACHINE_ID_DEST}" ]]; then
        log::info "${FUNCNAME[0]}: already persisted, skipping"
        return 0
    fi

    if [[ ! -f "${MACHINE_ID_SRC}" ]]; then
        log::warn "${FUNCNAME[0]}: ${MACHINE_ID_SRC} not found, skipping"
        return 0
    fi

    local id
    id="$(cat "${MACHINE_ID_SRC}")"

    if [[ "${id}" == "uninitialized" ]] || [[ -z "${id}" ]]; then
        log::warn "${FUNCNAME[0]}: machine-id not yet initialized, skipping — will retry next boot"
        return 0
    fi

    mkdir -p "$(dirname "${MACHINE_ID_DEST}")"
    cp "${MACHINE_ID_SRC}" "${MACHINE_ID_DEST}"
    chmod 444 "${MACHINE_ID_DEST}"
    log::info "${FUNCNAME[0]}: machine-id persisted: ${id}"
}

################################################################################
# EOF                                                                          #
################################################################################
