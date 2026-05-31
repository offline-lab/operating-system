#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

################################################################################
## Exit functions for scripts                                                 ##
################################################################################

#
# Print to log and exit with exit_code
#

function exit::log() {
    local message severity exit_code

    message="${1}"
    severity="${2}"
    exit_code="${3:-0}"

    log::trace "${FUNCNAME[0]}: Logging to output with ${severity} and exit ${exit_code}"

    log::logger "${message}" "${severity}"

    exit "${exit_code}"
}

#
# Print to log and exit OK
#

function exit::info() {
    local message exit_code

    log::trace "${FUNCNAME[0]}: Logging OK and exiting"

    message="${1}"
    exit_code="${2:-0}"

    exit::log "${message}" INFO "${exit_code}"
}

function exit::ok() { exit::info "${@}"; }

#
# Print debug to log and exit OK
#

function exit::debug() {
    local message exit_code

    log::trace "${FUNCNAME[0]}: Logging DEBUG and exiting"

    message="${1}"
    exit_code="${2:-0}"

    exit::log "${message}" DEBUG "${exit_code}"
}

#
# Print trace to log and exit OK
#

function exit::trace() {
    local message exit_code

    log::trace "${FUNCNAME[0]}: Logging TRACE and exiting"

    message="${1}"
    exit_code="${2:-0}"

    exit::log "${message}" TRACE "${exit_code}"
}

#
# Print warning to log and exit NOK
#

function exit::warning() {
    local message exit_code

    log::trace "${FUNCNAME[0]}: Logging WARNING and exiting"

    message="${1}"
    exit_code="${2:-1}"

    exit::log "${message}" WARNING "${exit_code}"
}

function exit::warn() { exit::warning "${@}"; }

#
# Print error to log and exit NOK
#

function exit::error() {
    local message exit_code

    log::trace "${FUNCNAME[0]}: Logging ERROR and exiting"

    message="${1}"
    exit_code="${2:-1}"

    exit::log "${message}" ERROR "${exit_code}"
}

function exit::err() { exit::error "${@}"; }
function exit::fatal() { exit::error "${@}"; }
function exit::die() { exit::error "${@}"; }

#
# Print output in white from stdin with level INPUT and exit
#

function exit::stdin() {
    log::trace "${FUNCNAME[0]}: Logging input"

    local -r level="${1:-INPUT}"
    local -i exit_code="${2:-0}"

    log::stdin "${level}" </dev/stdin

    exit "${exit_code}"
}

#
# Error out when input is false
#

function exit::if_false() {
    local value message severity exit_code

    log::trace "${FUNCNAME[0]}: Error out when input is false"

    value="${1:-}"
    message="${2:-}"
    severity="${3:-"ERROR"}"
    exit_code="${4:-1}"

    if var::is_false "${value}"; then
        exit::log "${message}" "${severity}" "${exit_code}"
    fi
}

#
# Error out if input is true
#

function exit::if_true() {
    local value message severity exit_code

    log::trace "${FUNCNAME[0]}: Error out when input is true"

    value="${1:-}"
    message="${2:-}"
    severity="${3:-"ERROR"}"
    exit_code="${4:-1}"

    if var::is_true "${value}"; then
        exit::log "${message}" "${severity}" "${exit_code}"
    fi
}

#
# Error out if input is empty
#

function exit::if_empty() {
    local value message severity exit_code

    log::trace "${FUNCNAME[0]}: Error out when input is empty"

    value="${1:-}"
    message="${2:-}"
    severity="${3:-ERROR}"
    exit_code="${4:-1}"

    if var::is_empty "${value}"; then
        exit::log "${message}" "${severity}" "${exit_code}"
    fi
}

#
# Error out if input is equal to
#

function exit::if_equals() {
    local value1 value2 message severity exit_code

    log::trace "${FUNCNAME[0]}: Error out when input value1 equals value2"

    value1="${1:-}"
    value2="${2:-}"
    message=${3:-}
    severity="${4:-"ERROR"}"
    exit_code="${5:-1}"

    if var::equals "${value1}" "${value2}"; then
        exit::log "${message}" "${severity}" "${exit_code}"
    fi
}

################################################################################
#                                                                              #
################################################################################
