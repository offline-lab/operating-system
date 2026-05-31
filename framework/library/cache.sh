#!/usr/bin/env bash
# vi: ft=bash

#
# Initialize cache
#

function cache::setup() {
    local dir="${1:-}"
    shift || true

    ## export the cache directory
    export cachedir="${dir:-"${HOME}/.local/cache/bash"}"

    log::trace "${FUNCNAME[0]}: Initializing cache in ${cachedir}"

    ## set to volatile if --volatile is passed
    if string::contains "--volatile" "${*}" || string::contains "-v" "${*}"; then

        ## Set the cache extension to the pid of the script
        export cache_extension="${$}"

        ## Clear out cache on exit, sigint and sigquit
        trap cache::flushall SIGINT SIGQUIT EXIT
    else
        export cache_extension="cache"
    fi

    ## Create cachedir
    if ! fs::is_dir "${cachedir}"; then
        if ! mkdir -p "${cachedir}"; then
            log::error "${FUNCNAME[0]}: Failed to create ${cachedir}"
            return 1
        else
            cache::set "initialized" "$(date || true)" || return 1
        fi
    fi

    return 0
}

#
# Check of cache is initialized
#
function cache::is_initialized() {
    log::trace "${FUNCNAME[0]}: Checking if cache key is initialized"

    if var::is_null "${cachedir:-}" || var::is_null "${cache_extension:-}"; then
        return 1
    fi

    return 0
}

#
# Print a warning if cache is not initialized
#

function cache::warning() {
    log::trace "${FUNCNAME[0]}: Checking if cache is initialized"

    if ! cache::is_initialized; then
        log::warning "${FUNCNAME[0]}: Cache is not initialized!"
    fi
}

#
# Check if cache item exists
#

function cache::exists() {
    log::trace "${FUNCNAME[0]}: Checking if cache key ${1} exists"

    [[ "${#}" -ne 1 ]] && return 2

    local key="${1}"
    shift

    [[ -z "${cachedir:-}" || -z "${cache_extension:-}" ]] && return 1

    fs::is_file "${cachedir}/${key}.${cache_extension}"
}

#
# Get key from cache
#

function cache::get() {
    log::trace "${FUNCNAME[0]}: Retrieving key from cache"

    [[ "${#}" -ne 1 ]] && return 2

    local key="${1}"
    shift

    if ! cache::exists "${key}"; then
        return 1
    fi

    if ! printf "%s" "$(<"${cachedir}/${key}.${cache_extension}")"; then
        log::error "${FUNCNAME[0]}: Failed to retrieve ${key} from cache"
        return 1
    fi

    return 0
}

#
# Set key in cache
#

function cache::set() {
    [[ "${#}" -ne 2 ]] && return 2

    local key="${1}"
    shift

    local value="${1}"
    shift

    log::trace "${FUNCNAME[0]}: Setting ${key}:${value} in cache"

    cache::warning || return 1

    if ! printf "%s" "${value}" >"${cachedir}/${key}.${cache_extension}"; then
        log::error "${FUNCNAME[0]}: Failed to set ${key} in cache"
        return 1
    fi

    return 0
}

#
# Remove key from cache
#

function cache::flush() {
    [[ "${#}" -ne 1 ]] && return 2

    local key="${1}"
    shift

    log::trace "${FUNCNAME[0]}: Flushing ${key} from cache"

    cache::warning || return 1

    if ! rm -f "${cachedir}/${key}.${cache_extension}"; then
        log::error "${FUNCNAME[0]}: An error while flushing ${key} from cache"
        return 1
    fi

    return 0
}

#
# Clear out the cache
#

function cache::flushall() {
    log::trace "${FUNCNAME[0]}: Flushing all keys from cache"

    cache::warning || return 1

    if ! fs::is_dir "${cachedir}"; then
        return 0
    fi

    if ! rm -rf "${cachedir}"; then
        log::error "${FUNCNAME[0]}: Could not flush cache"
        return 1
    fi

    return 0
}
