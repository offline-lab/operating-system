#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

################################################################################
## FS:: Filesystem helpers                                                    ##
################################################################################

#
# Check if directory and existent
#

function fs::is_dir() {
    log::trace "${FUNCNAME[0]}: Checking if directory exists"

    [[ "${#}" -ne 1 ]] && return 2

    local input="${1:-}"
    shift

    [[ -d "${input}" ]]
}

#
# Check if file and existent
#

function fs::is_file() {
    log::trace "${FUNCNAME[0]}: Checking if file exists"

    [[ "${#}" -ne 1 ]] && return 2

    local input="${1:-}"
    shift

    [[ -f "${input}" ]]
}

#
# Check if device and existent
#

function fs::is_blockdev() {
    log::trace "${FUNCNAME[0]}: Checking if block device exists"

    [[ "${#}" -ne 1 ]] && return 2

    local input="${1:-}"
    shift

    [[ -b "${input}" ]]
}

function fs::is_device() { fs::is_blockdev "${@}"; }

#
# Check if socket and existent
#

function fs::is_socket() {
    log::trace "${FUNCNAME[0]}: Checking if socket exists"

    [[ "${#}" -ne 1 ]] && return 2

    local input="${1:-}"
    shift

    [[ -S "${input}" ]]
}

#
# Check if input is a character special device
#

function fs::is_chardev() {
    log::trace "${FUNCNAME[0]}: Checking if char device exists"

    [[ "${#}" -ne 1 ]] && return 2

    local input="${1:-}"
    shift

    [[ -c "${input}" ]]
}

#
# Check if pipe and existent
#

function fs::is_pipe() {
    log::trace "${FUNCNAME[0]}: Checking if pipe exists"

    [[ "${#}" -ne 1 ]] && return 2

    local input="${1:-}"
    shift

    [[ -p "${input}" ]]
}

#
# Check if open port / listening socket
#

function fs::is_port() {
    log::trace "${FUNCNAME[0]}: Checking if port is in use"

    [[ "${#}" -ne 1 ]] && return 2

    local input="${1}"
    shift

    # ss is part of iproute2, available on the device image
    depends::check::silent ss || return 1

    ss -tlnp "sport = :${input}" 2>/dev/null | grep -q LISTEN
}

#
# Check if symlink and existent
#

function fs::is_link() {
    log::trace "${FUNCNAME[0]}: Checking if symlink exists"

    [[ "${#}" -ne 1 ]] && return 2

    local input="${1:-}"
    shift

    [[ -L "${input}" ]]
}

#
# Check if executable and existent
#

function fs::is_executable() {
    log::trace "${FUNCNAME[0]}: Checking if file is executable"

    [[ "${#}" -ne 1 ]] && return 2

    local input="${1:-}"
    shift

    [[ -x "${input}" ]]
}

#
# Check if existent
#

function fs::exists() {
    log::trace "${FUNCNAME[0]}: Checking if path exists"

    [[ "${#}" -ne 1 ]] && return 2

    local input="${1:-}"
    shift

    [[ -e "${input}" ]]
}

#
# Check if file matches regex
#

function fs::is_regex() {
    local file regex

    log::trace "${FUNCNAME[0]}: Checking if file matches regex"

    file="${1:-}"
    shift

    regex="${1:-}"
    shift

    local -a arguments=("${@}")

    if [[ "${#arguments[@]}" -eq 0 ]]; then
        arguments+=(-E)
    fi

    fs::exists "${file}" || return 1

    # shellcheck disable=SC2086
    grep -q "${arguments[@]}" -- "${regex}" "${file}"
}

#
# Check how many times a regex occurs in a file
#

function fs::regex_count() {
    local file regex

    log::trace "${FUNCNAME[0]}: Checking how many times regex matches in file"

    file="${1:-}"
    shift

    regex="${1:-}"
    shift

    local -a arguments=("${@}")

    if [[ "${#arguments[@]}" -eq 0 ]]; then
        arguments+=(-E)
    fi

    fs::exists "${file}" || return 1

    # shellcheck disable=SC2086
    grep -c "${arguments[@]}" -- "${regex}" "${file}"
}

################################################################################
# Directory helper functions                                                   #
################################################################################

#
# Check if the directory of a file exists
#
function fs::in_dir() {
    local file directory

    log::trace "${FUNCNAME[0]}: Check if directory containing file exists"

    file="${1:-}"
    shift

    directory="$(dirname "${file}" || true)"

    fs::is_dir "${directory}"
}

#
# Make sure the directory of a file exists
#
function fs::ensure_dir() {
    local file directory

    log::trace "${FUNCNAME[0]}: Making sure directory exists"

    file="${1:-}"
    shift

    directory="$(dirname "${file}" || true)"

    if fs::in_dir "${file}"; then
        return 0
    fi

    if ! mkdir -p "${directory}"; then
        log::error "${FUNCNAME[0]}: Failed to create directory ${directory}!"
        return 1
    fi
}

#
# Make sure a directory and a file exist
#
function fs::ensure_file_in_dir() {
    local file

    log::trace "${FUNCNAME[0]}: Making sure file exists in directory"

    file="${1:-}"
    shift

    fs::ensure_dir "${file}" || return 1

    if ! fs::exists "${file}"; then
        touch "${file}" || return 1
    fi
}

################################################################################
# EOF                                                                          #
################################################################################
