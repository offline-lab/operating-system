#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

################################################################################
# Run a command and handle output                                              #
################################################################################

#
# Run a command silently; print combined output only on failure.
# Bash port of moreutils chronic(1) — https://joeyh.name/code/moreutils/
#
function proc::chronic() {
    log::trace "${FUNCNAME[0]}: Running command with output suppressed unless failure"

    [[ "${#}" -eq 0 ]] && return 2

    local tmpfile rc

    tmpfile="$(mktemp)" || return 1
    rc=0

    "${@}" >"${tmpfile}" 2>&1 || rc="${?}"

    if [[ "${rc}" -ne 0 ]]; then
        cat "${tmpfile}" >&2
    fi

    rm -f "${tmpfile}"
    return "${rc}"
}

#
# Run a command and send all output to a file
#

function proc::assert_command() {
    log::trace "${FUNCNAME[0]}: Running command and capturing output"

    [[ "${#}" -lt 2 ]] && return 2

    local outfile="${1}"
    shift

    local -a execution_string=("${@}")

    if ! fs::exists "${outfile}"; then
        log::error "${FUNCNAME[0]}: Output file ${outfile} nonexistent!"
        return 1
    fi

    if "${execution_string[@]}" >"${outfile}" 2>&1; then
        return 0
    fi

    return 1
}

#
# Run a command and send all output to logger
#

function proc::log_output() {
    log::trace "${FUNCNAME[0]}: Running command and sending output to log"

    [[ "${#}" -lt 2 ]] && return 2

    local severity="${1}"
    shift

    local -a execution_string=("${@}")

    (set -o pipefail && "${execution_string[@]}" 2>&1 | log::stdin "${severity}")

    return "${?}"
}

#
# Run a command and log the output based on it's exit code
#

function proc::log_action() {
    log::trace "${FUNCNAME[0]}: Running command and logging output by exit code"

    [[ "${#}" -lt 1 ]] && return 2

    local tmpfile
    local -a execution_string=("${@}")

    if ! tmpfile="$(mktemp)"; then
        log::error "${FUNCNAME[0]}: Failed to request proc::tmpfile"
        return 1
    fi

    log::info "${FUNCNAME[0]}: Running command: ${execution_string[*]}"

    if ! proc::assert_command "${tmpfile}" "${execution_string[@]}"; then
        log::error "${FUNCNAME[0]}: Failed to run ${execution_string[*]}"
        log::stdin ERROR <"${tmpfile}" && rm "${tmpfile}"
        return 1
    fi

    log::info "${FUNCNAME[0]}: Command ${execution_string[*]} succeeded"
    log::stdin DEBUG <"${tmpfile}" && rm "${tmpfile}"

    return 0

}

#
# Watch a command
#

function proc::watch() {
    log::trace "${FUNCNAME[0]}: Watching command"

    [[ "${#}" -lt 1 ]] && return 2

    local command="${1}"
    shift

    local -a arguments=("${@}")

    command watch "${arguments[@]}" -- "${command}"
}

#
# Run a command silently; echoes "true"/"false" to stdout, returns 0/1.
#
function proc::run() {
    log::trace "${FUNCNAME[0]}: Running command silently"

    [[ "${#}" -lt 1 ]] && return 2

    local -a command=("${@}")

    if proc::chronic "${command[@]}"; then
        echo true
        return 0
    fi

    echo false
    return 1
}

#
# Run a set of commands and return a list of trues and/or falses
#
function proc::runall() {
    log::trace "${FUNCNAME[0]}: Running list of commands"

    [[ "${#}" -lt 1 ]] && return 2

    local -a commands=("${@}")
    local -i exitcode=0

    for command in "${commands[@]}"; do
        local success

        success="$(proc::run "${command}")"

        if ! var::equals "${success}" true; then
            exitcode=1
        fi

        echo "${success}"
    done

    return "${exitcode}"
}

#
# Return zero if all commands succeed
#
function proc::all() {
    log::trace "${FUNCNAME[0]}: Running all check"

    [[ "${#}" -lt 1 ]] && return 2

    local -a commands=("${@}")
    local -a output

    readarray -t output < <(proc::runall "${commands[@]}")

    array::alltrue "${output[@]}"
}

#
# Return zero if any of the commands succeed
#
function proc::any() {
    log::trace "${FUNCNAME[0]}: Running any check"

    [[ "${#}" -lt 1 ]] && return 2

    local -a commands=("${@}")
    local -a output

    readarray -t output < <(proc::runall "${commands[@]}")

    array::anytrue "${output[@]}"
}

#
# Return zero if none of the commands succeed
#
function proc::none() {
    log::trace "${FUNCNAME[0]}: Running none check"

    [[ "${#}" -lt 1 ]] && return 2

    local -a commands=("${@}")
    local -a output

    readarray -t output < <(proc::runall "${commands[@]}")

    ! array::anytrue "${output[@]}"
}

################################################################################
# EOF                                                                          #
################################################################################
