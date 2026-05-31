#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

#
# Format the --flag into a variable name
#
function arguments::get_variable_name() {
    log::trace "${FUNCNAME[0]}: Get the variable name for a script argument"

    [[ "${#}" -lt 1 || "${#}" -gt 2 ]] && return 2

    local argument prefix

    argument="${1}"
    prefix="${2:-arguments}"

    argument="${argument#--}"
    argument="${argument#-}"
    argument="${argument//[-.]/_}"
    argument="${argument//[^a-zA-Z0-9_]/}"

    if [[ "${argument}" =~ ^[0-9] ]]; then
        argument="_${argument}"
    fi

    echo "${prefix}_${argument}"
}

#
# Parse the arguments into a dict
#
function arguments::parse_arguments() {

    log::trace "${FUNCNAME[0]}: Parse arguments"

    local prefix="${1:-arguments}"
    shift

    # Unset globals written by the previous call before reinitialising
    local _k
    for _k in "${!parsed_arguments[@]}"; do
        unset "${_k}" 2>/dev/null || true
    done

    declare -gA parsed_arguments=()

    while [[ "${#}" -gt 0 ]]; do

        local argument="${1}"
        local key value varname

        if [[ "${argument}" =~ ^--?([^=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            varname=$(arguments::get_variable_name "--${key}" "${prefix}")

            parsed_arguments["${varname}"]="${value}"

            declare -g "${varname}=${value}"
            shift

        elif [[ "${argument}" =~ ^--?(.+)$ ]]; then
            key="${BASH_REMATCH[1]}"
            varname=$(arguments::get_variable_name "--${key}" "${prefix}")

            if [[ "${#}" -gt 1 && ! "${2}" =~ ^- ]]; then
                parsed_arguments["${varname}"]="${2}"

                declare -g "${varname}=${2}"
                shift 2
            else
                parsed_arguments["${varname}"]="true"

                declare -g "${varname}=true"
                shift
            fi
        else
            shift
        fi
    done

}

#
# Check if a specific argument is given
#

function arguments::in_args() {
    log::trace "${FUNCNAME[0]}: Checking if flag is present in arguments"

    [[ "${#}" -lt 2 ]] && return 2

    local argument="${1}"
    shift
    local input="${*}"

    if var::matches "${input}" "${argument}"; then
        return 0
    fi

    return 1
}
