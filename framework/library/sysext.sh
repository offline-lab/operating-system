#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

# System extension (sysext) operations via systemd-sysext.
# All mutating functions require root (called via priv::run).

_SYSEXT_DIR="${_SYSEXT_DIR:-/data/extensions/sysext}"

function sysext::list() {
    log::trace "${FUNCNAME[0]}: listing system extensions"
    depends::check::silent systemd-sysext || return 1
    priv::run systemd-sysext list
}

function sysext::status() {
    log::trace "${FUNCNAME[0]}: showing system extension merge status"
    depends::check::silent systemd-sysext || return 1
    priv::run systemd-sysext status
}

function sysext::merge() {
    log::trace "${FUNCNAME[0]}: merging system extensions"
    depends::check::silent systemd-sysext || return 1
    priv::run systemd-sysext merge
}

function sysext::unmerge() {
    log::trace "${FUNCNAME[0]}: unmerging system extensions"
    depends::check::silent systemd-sysext || return 1
    priv::run systemd-sysext unmerge
}

function sysext::refresh() {
    log::trace "${FUNCNAME[0]}: refreshing system extensions (unmerge + merge)"
    depends::check::silent systemd-sysext || return 1
    priv::run systemd-sysext refresh
}

function sysext::storage_dir() {
    log::trace "${FUNCNAME[0]}: returning sysext storage directory"
    printf '%s\n' "${_SYSEXT_DIR}"
}
