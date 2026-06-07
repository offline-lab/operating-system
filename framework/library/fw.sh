#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

_FW_STATIC="${_FW_STATIC:-/etc/firewall/rules.fw}"
_FW_APP_DIR="${_FW_APP_DIR:-/data/config/firewall/rules.d}"
_FW_STATE="${_FW_STATE:-/run/firewall.state}"

################################################################################
# fw::flush — clear all nftables rules                                         #
################################################################################

function fw::flush() {
    log::trace "${FUNCNAME[0]}: flush ruleset and clear state"
    depends::check::silent nft || return 1

    nft flush ruleset
    rm -f "${_FW_STATE}"
}

################################################################################
# fw::down — explicit "firewall is down" with a log warning                    #
################################################################################

function fw::down() {
    log::trace "${FUNCNAME[0]}: bring firewall completely down"
    fw::flush || return 1
    log::warn "${FUNCNAME[0]}: firewall is DOWN — all traffic allowed"
}

################################################################################
# fw::_load_static — load static rules from rootfs                             #
################################################################################

function fw::_load_static() {
    log::trace "${FUNCNAME[0]}: load static rules from ${_FW_STATIC}"
    depends::check::silent nft || return 1

    if [[ ! -f "${_FW_STATIC}" ]]; then
        log::error "${FUNCNAME[0]}: ${_FW_STATIC} not found"
        return 1
    fi

    nft -f "${_FW_STATIC}" || return 1
}

################################################################################
# fw::_load_apps — replay all per-app rule fragments                           #
################################################################################

function fw::_restore_fragment() {
    [[ "${#}" -ne 1 ]] && return 2
    local fragment="${1}"
    shift
    # Each fragment contains nft add-rule commands, one per line.
    # nft -f interprets them non-destructively against the existing ruleset.
    nft -f "${fragment}"
}

function fw::_load_apps() {
    log::trace "${FUNCNAME[0]}: load app rule fragments from ${_FW_APP_DIR}"
    [[ -d "${_FW_APP_DIR}" ]] || return 0

    local fragment
    for fragment in "${_FW_APP_DIR}"/*.rules; do
        [[ -f "${fragment}" ]] || continue
        fw::_restore_fragment "${fragment}" ||
            log::warn "${FUNCNAME[0]}: failed to load ${fragment}"
    done
}

################################################################################
# fw::up — full bring-up: flush + static + apps                                #
################################################################################

function fw::up() {
    log::trace "${FUNCNAME[0]}: bring firewall up"
    fw::flush || return 1
    fw::_load_static || return 1
    fw::_load_apps
    touch "${_FW_STATE}"
    log::info "${FUNCNAME[0]}: firewall is UP"
}

################################################################################
# fw::reload — alias for fw::up                                                #
################################################################################

function fw::reload() {
    log::trace "${FUNCNAME[0]}: reload all firewall rules"
    fw::up
}

################################################################################
# fw::reset — static rules only, drop all app rules from memory                #
################################################################################

function fw::reset() {
    log::trace "${FUNCNAME[0]}: reset to static rules only"
    fw::flush || return 1
    fw::_load_static || return 1
    touch "${_FW_STATE}"
    log::info "${FUNCNAME[0]}: firewall reset to static rules"
}

################################################################################
# fw::init — bring up only if not already up (idempotent; safe for systemd)   #
################################################################################

function fw::init() {
    log::trace "${FUNCNAME[0]}: initialize firewall if not already up"
    [[ -f "${_FW_STATE}" ]] && return 0
    fw::up
}

################################################################################
# fw::app_allow <app> <proto> <port>                                           #
################################################################################

function fw::app_allow() {
    [[ "${#}" -ne 3 ]] && return 2

    local app="${1}" proto="${2}" port="${3}"
    shift 3

    log::trace "${FUNCNAME[0]}: allow ${proto}/${port} for app ${app}"
    depends::check::silent nft || return 1

    local fragment="${_FW_APP_DIR}/${app}.rules"
    local rule="add rule inet filter input ${proto} dport ${port} accept"

    mkdir -p "${_FW_APP_DIR}"

    if [[ -f "${fragment}" ]] && grep -qxF -- "${rule}" "${fragment}"; then
        return 0
    fi

    printf '%s\n' "${rule}" >>"${fragment}"

    if [[ -f "${_FW_STATE}" ]]; then
        nft add rule inet filter input "${proto}" dport "${port}" accept || return 1
    fi
}

################################################################################
# fw::app_remove <app>                                                         #
################################################################################

function fw::app_remove() {
    [[ "${#}" -ne 1 ]] && return 2

    local app="${1}"
    shift

    log::trace "${FUNCNAME[0]}: remove app ${app} firewall rules"
    rm -f "${_FW_APP_DIR}/${app}.rules"
    fw::up
}

################################################################################
# fw::list                                                                     #
################################################################################

function fw::list() {
    log::trace "${FUNCNAME[0]}: list current firewall rules"
    depends::check::silent nft || return 1
    nft list ruleset
}

################################################################################
# EOF                                                                          #
################################################################################
