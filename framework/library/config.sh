#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

# /data/config read/write helpers for boxctl.
# All functions require the framework to be sourced before this file.

CONFIG_DIR="${CONFIG_DIR:-/data/config}"

function config::ensure_writable() {
    log::trace "${FUNCNAME[0]}: Checking ${CONFIG_DIR} is writable"

    if [[ ! -d "${CONFIG_DIR}" ]]; then
        log::error "${FUNCNAME[0]}: ${CONFIG_DIR} does not exist — is /data mounted?"
        return 1
    fi

    if [[ ! -w "${CONFIG_DIR}" ]]; then
        log::error "${FUNCNAME[0]}: ${CONFIG_DIR} is not writable"
        return 1
    fi
}

function config::read() {
    local file

    log::trace "${FUNCNAME[0]}: Reading ${1}"

    [[ "${#}" -ne 1 ]] && return 2

    file="${CONFIG_DIR}/${1}"

    [[ ! -f "${file}" ]] && return 1
    cat "${file}"
}

function config::write() {
    local key value

    log::trace "${FUNCNAME[0]}: Writing ${1}"

    [[ "${#}" -ne 2 ]] && return 2

    key="${1}"
    value="${2}"

    config::ensure_writable || return 1

    mkdir -p "$(dirname "${CONFIG_DIR}/${key}")"

    printf '%s\n' "${value}" >"${CONFIG_DIR}/${key}"
}

function config::delete() {
    local file

    log::trace "${FUNCNAME[0]}: Deleting ${1}"

    [[ "${#}" -ne 1 ]] && return 2

    file="${CONFIG_DIR}/${1}"

    [[ -f "${file}" ]] && rm -f "${file}"
    return 0
}

function config::list() {
    log::trace "${FUNCNAME[0]}: Listing config keys"

    [[ ! -d "${CONFIG_DIR}" ]] && return 1

    find "${CONFIG_DIR}" -type f | sed "s|${CONFIG_DIR}/||" | sort
}

function config::apply_hostname() {
    local hostname

    log::trace "${FUNCNAME[0]}: Applying hostname from config"

    hostname="$(config::read hostname)" || {
        log::warning "${FUNCNAME[0]}: No hostname in config"
        return 0
    }

    depends::check::silent hostnamectl || return 1

    priv::run hostnamectl set-hostname "${hostname}"
}

function config::apply_timezone() {
    local tz

    log::trace "${FUNCNAME[0]}: Applying timezone from config"

    tz="$(config::read timezone)" || {
        log::warning "${FUNCNAME[0]}: No timezone in config"
        return 0
    }

    depends::check::silent timedatectl || return 1

    priv::run timedatectl set-timezone "${tz}"
}
