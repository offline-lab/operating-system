#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

################################################################################
# Sanity checker                                                               #
################################################################################

function sanity::check() {
    local input="${1}"

    log::trace "${FUNCNAME[0]}: Retrieving and importing sanity checks"

    if var::is_empty "${SANITY_CHECK_PATH:-}"; then
        log::warn "${FUNCNAME[0]}: SANITY_CHECK_PATH is not set, no checks to run"
        return 0
    fi

    ## Source all sanity checks
    for testfile in "${SANITY_CHECK_PATH}"/*.sh; do
        fs::is_file "${testfile}" || continue

        # Verbose output
        var::has_value "${input}" &&
            log::info "${FUNCNAME[0]}: Loading file ${testfile}"

        # shellcheck source=/dev/null
        source "${testfile}"
    done

    local failed=0

    log::info "${FUNCNAME[*]}: Running sanity checks"

    ## Run all defined sanity checks
    for sanity_check in $(
        declare -F |
            awk '/sanity::check::/ {print $NF}' |
            grep -v '^sanity::check$' |
            sort -u
    ); do
        var::has_value "${input}" &&
            log::info "${FUNCNAME[0]}: Running check ${sanity_check}"

        if ! "${sanity_check}"; then
            ((failed++))
        fi

        ## Remove function after use
        unset -f "${sanity_check}"

    done

    if var::ne "${failed}" 0; then
        log::error "${FUNCNAME[0]}: Not all sanity checks succeeded"
        return 1
    fi

    return 0
}

################################################################################
#                                                                              #
################################################################################
