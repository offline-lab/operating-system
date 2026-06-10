#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

CLOCK_FILE="${CLOCK_FILE:-/data/config/fake-hwclock.data}"

function clock::load() {
    log::trace "${FUNCNAME[0]}: restoring system clock"
    fs::is_file "${CLOCK_FILE}" || return 0
    local saved_time
    saved_time="$(cat "${CLOCK_FILE}")"
    date -u -s "${saved_time}" >/dev/null 2>&1 || true
    log::info "${FUNCNAME[0]}: restored to ${saved_time}"
}

function clock::save() {
    log::trace "${FUNCNAME[0]}: saving system clock"
    fs::ensure_dir "${CLOCK_FILE}"
    date -u '+%Y-%m-%d %H:%M:%S' >"${CLOCK_FILE}"
    log::info "${FUNCNAME[0]}: saved"
}
