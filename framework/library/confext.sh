#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

# Configuration extension (confext) operations via systemd-confext.
# All mutating functions require root (called via priv::run).

_CONFEXT_DIR="${_CONFEXT_DIR:-/data/extensions/confext}"

function confext::list() {
    log::trace "${FUNCNAME[0]}: listing configuration extensions"
    depends::check::silent systemd-confext || return 1
    priv::run systemd-confext list
}

function confext::status() {
    log::trace "${FUNCNAME[0]}: showing configuration extension merge status"
    depends::check::silent systemd-confext || return 1
    priv::run systemd-confext status
}

function confext::merge() {
    log::trace "${FUNCNAME[0]}: merging configuration extensions"
    depends::check::silent systemd-confext || return 1
    priv::run systemd-confext merge
}

function confext::unmerge() {
    log::trace "${FUNCNAME[0]}: unmerging configuration extensions"
    depends::check::silent systemd-confext || return 1
    priv::run systemd-confext unmerge
}

function confext::refresh() {
    log::trace "${FUNCNAME[0]}: refreshing configuration extensions (unmerge + merge)"
    depends::check::silent systemd-confext || return 1
    priv::run systemd-confext refresh
}

function confext::storage_dir() {
    log::trace "${FUNCNAME[0]}: returning confext storage directory"
    printf '%s\n' "${_CONFEXT_DIR}"
}
