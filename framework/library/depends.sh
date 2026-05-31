#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

################################################################################
# Check if user is root                                                        #
################################################################################

function depends::is_root() {
    log::trace "${FUNCNAME[0]}: Checking if current user is superuser"

    [[ "$(whoami || true)" == root ]]
}

################################################################################
# Check if dependency is found in PATH                                         #
################################################################################

function depends::in_path() {
    log::trace "${FUNCNAME[0]}: Checking if dependency is in path"

    [[ "${#}" -ne 1 ]] && return 2

    local command="${1}"

    fs::exists "$(command -v "${command}" || true)"
}

################################################################################
# Check if dependency is executable                                            #
################################################################################

function depends::executable() {
    log::trace "${FUNCNAME[0]}: Checking if dependency is executable"

    [[ "${#}" -ne 1 ]] && return 2

    local command="${1}"

    fs::is_executable "$(command -v "${command}" || true)"
}

################################################################################
# Silently check if dependency exists                                          #
################################################################################

function depends::check::silent() {
    log::trace "${FUNCNAME[0]}: Checking if dependency exists"

    [[ "${#}" -ne 1 ]] && return 2

    local command="${1}"

    depends::executable "${command}"
}

################################################################################
# Check if dependency exists (and log it)                                      #
################################################################################

function depends::check() {
    log::trace "${FUNCNAME[0]}: Checking for required dependency"

    [[ "${#}" -ne 1 ]] && return 2

    local command="${1}"

    if ! depends::executable "${command}"; then
        log::error "${FUNCNAME[0]}: Missing requirement: ${command}"
        return 1
    fi
}

################################################################################
# Check silently if a list of dependencies exist                               #
################################################################################

function depends::check_list::silent() {
    log::trace "${FUNCNAME[0]}: Checking list of dependencies silently"

    [[ "${#}" -lt 1 ]] && return 2

    local -a requirements=("${@}")

    for dependency in "${requirements[@]}"; do
        depends::executable "${dependency}" || return 1
    done
}

################################################################################
# Check if a list of dependencies exist (and log it)                           #
################################################################################

function depends::check_list() {
    log::trace "${FUNCNAME[0]}: Checking for list of dependencies"

    [[ "${#}" -lt 1 ]] && return 2

    local -a requirements=("${@}")
    local missing=0
    local missing_names=""

    for dependency in "${requirements[@]}"; do
        log::trace "${FUNCNAME[0]}: Checking for dependency ${dependency}"

        if ! depends::executable "${dependency}"; then
            missing=$((missing + 1))
            missing_names="${missing_names} ${dependency}"
        fi
    done

    if [[ "${missing}" -ne 0 ]]; then
        log::error "${FUNCNAME[0]}: Missing utils:${missing_names}"
        return 1
    fi
}

################################################################################
# EOF                                                                          #
################################################################################
