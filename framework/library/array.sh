#!/usr/bin/env bash
# vi: ft=bash

################################################################################
# Array size comparison                                                        #
################################################################################

#
# Get the length of an array
#

function array::length() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    log::trace "${FUNCNAME[0]}: Retrieving length of array"

    local -a array=("${@}")

    printf "%s" "${#array[@]}"
}

#
# Check if array size is less than N
#
function array::lt() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local input
    local -a array=()

    input="${1}"
    shift

    array=("${@}")

    var::is_numeric "${input}" || return 2

    log::trace "${FUNCNAME[0]}: Check if array size is less than N"

    if [[ "${#array[@]}" -lt "${input}" ]]; then
        return 0
    fi

    return 1
}

#
# Check if array is less than or equal to N
#
function array::le() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local input
    local -a array=()

    input="${1}"
    shift

    array=("${@}")

    var::is_numeric "${input}" || return 2

    log::trace "${FUNCNAME[0]}: Check if array is less than or equal to N"

    if [[ "${#array[@]}" -le "${input}" ]]; then
        return 0
    fi

    return 1
}

#
# Check if array size is greater than N
#
function array::gt() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local input
    local -a array=()

    input="${1}"
    shift

    array=("${@}")

    var::is_numeric "${input}" || return 2

    log::trace "${FUNCNAME[0]}: Check if array size is greater than N"

    if [[ "${#array[@]}" -gt "${input}" ]]; then
        return 0
    fi

    return 1
}

#
# Check if array size is greater than or equal to N
#
function array::ge() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local input="${1}"
    shift

    local -a array=("${@}")

    var::is_numeric "${input}" || return 2

    log::trace "${FUNCNAME[0]}: Check if array size is greater than or equal to N"

    if [[ "${#array[@]}" -ge "${input}" ]]; then
        return 0
    fi

    return 1
}

#
# Check if array size is equal to N
#
function array::eq() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local input="${1}"
    shift

    local -a array=("${@}")

    var::is_numeric "${input}" || return 2

    log::trace "${FUNCNAME[0]}: Check if array size is equal to N"

    if [[ "${#array[@]}" -eq "${input}" ]]; then
        return 0
    fi

    return 1
}

#
# Check if array size is not equal to N
#
function array::ne() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local input="${1}"
    shift

    local -a array=("${@}")

    var::is_numeric "${input}" || return 2

    log::trace "${FUNCNAME[0]}: Check if array size is not equal to N"

    if [[ "${#array[@]}" -ne "${input}" ]]; then
        return 0
    fi

    return 1
}

################################################################################
# Array content comparison                                                     #
################################################################################

#
# Check if array contains element
#
function array::contains() { #
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local needle="${1}"
    shift

    local -a haystack=("${@}")

    log::trace "${FUNCNAME[0]}: Check if array contains ${needle}"

    for element in "${haystack[@]}"; do
        if var::equals "${element}" "${needle}"; then
            return 0
        fi
    done

    return 1
}

#
# Remove duplicate fields from an array
#

function array::deduplicate() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local -A arr_tmp
    local -a arr_unique

    log::trace "${FUNCNAME[0]}: Deduplicating array"

    for i in "${@}"; do
        { [[ -z ${i:-} ]] || [[ -n "${arr_tmp[${i}]}" ]]; } && continue

        arr_unique+=("${i}") && arr_tmp[${i}]=x
    done

    printf '%s\n' "${arr_unique[@]}"
}

#
# Check if array is empty
#

function array::is_empty() {
    log::trace "${FUNCNAME[0]}: Check if array is empty"

    local -a array=("${@}")

    if [[ ${#array[@]} -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

#
# Check if an array is not empty
#

function array::not_empty() {
    log::trace "${FUNCNAME[0]}: Check if array is not empty"

    local -a array=("${@}")

    if [[ ${#array[@]} -eq 0 ]]; then
        return 1
    else
        return 0
    fi
}

#
# Join all fields in an array with a separator string or char
#

function array::join() {
    log::trace "${FUNCNAME[0]}: Joining array with delimiter"

    [[ "${#}" -lt 1 ]] && return 2

    local delimiter="${1}"
    shift

    printf "%s" "${1}"
    shift

    printf "%s" "${@/#/${delimiter}}"
}

#
# Reverse the order of an array
#

function array::reverse() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local min=0
    local -a array=("${@}")
    local max=$((${#array[@]} - 1))

    log::trace "${FUNCNAME[0]}: Reversing array"

    while [[ "${min}" -lt "${max}" ]]; do
        # Swap current first and last elements
        x="${array[${min}]}"

        array[min]="${array[${max}]}"
        array[max]="${x}"

        # Move closer
        ((min++, max--))
    done

    printf '%s\n' "${array[@]}"
}

#
# Retrieve a random element from an array
#

function array::random_element() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local -a array=("${@}")

    log::trace "${FUNCNAME[0]}: Printing random element from array"

    printf '%s\n' "${array[RANDOM % "${#}"]}"
}

#
# Sort a numeric array
#

function array::sort() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local -a array=("${@}")
    local -a sorted
    local noglobtate

    log::trace "${FUNCNAME[0]}: Sorting array"

    noglobtate="$(shopt -po noglob)"

    set -o noglob

    local IFS=$'\n'

    mapfile -t sorted < <(sort <<<"${array[*]}" || true)

    unset IFS

    eval "${noglobtate}"

    printf "%s\n" "${sorted[@]}"
}

#
# Reverse sort a numeric array
#

function array::sort-r() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local -a array=("${@}")
    local -a sorted
    local noglobstate

    log::trace "${FUNCNAME[0]}: Sorting array reversed"

    noglobstate="$(shopt -po noglob)"

    set -o noglob

    local IFS=$'\n'

    mapfile -t sorted < <(sort -r <<<"${array[*]}" || true)

    unset IFS

    eval "${noglobstate}"

    printf "%s\n" "${sorted[@]}"
}

#
# Remove an element from an array by name
#

function array::pop_by_name() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local name="${1:-}"
    shift

    local -a array=("${@}")
    local -a output
    local noglobstate

    log::trace "${FUNCNAME[0]}: Popping element ${name} from array"

    noglobstate="$(shopt -po noglob)"

    set -o noglob

    local IFS=$'\n'

    for item in "${array[@]}"; do
        if [[ "${item}" != "${name}" ]]; then
            output+=("${item}")
        fi
    done

    unset IFS

    eval "${noglobstate}"

    printf "%s\n" "${output[@]}"
}

#
# Remove an element from an array by position
#

function array::pop_by_position() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local input="${1}"
    shift

    local -a array=("${@}")

    var::is_numeric "${input}" || return 2

    log::trace "${FUNCNAME[0]}: Popping element ${input} from array"

    unset "array[${input}]"

    printf "%s\n" "${array[@]}"
}

#
# Get the first element of an array
#

function array::first() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local -a array=("${@}")

    log::trace "${FUNCNAME[0]}: Printing first element from array"

    printf "%s\n" "${array[0]}"
}

#
# Get the last element of an array
#

function array::last() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local -a array=("${@}")

    log::trace "${FUNCNAME[0]}: Printing last element from array"

    printf "%s\n" "${array[-1]}"

}

#
# Get the Nth element of an array
#

function array::get() {
    if [[ "${#}" -lt 1 ]]; then
        log::warning "%s: Missing arguments" "${FUNCNAME[0]}"
        return 2
    fi

    local input="${1}"
    shift

    local -a array=("${@}")

    var::is_numeric "${input}" || return 2

    log::trace "${FUNCNAME[0]}: Printing ${input}th element from array"

    printf "%s\n" "${array[${input}]}"
}

#
# Return 0 if all of the elements are of value N
#
function array::all() {
    log::trace "${FUNCNAME[0]}: Checking if all elements equal value"

    [[ "${#}" -lt 2 ]] && return 2

    local value="${1}"
    shift

    local -a elements=("${@}")

    for element in "${elements[@]}"; do
        if ! var::equals "${value}" "${element}"; then
            return 1
        fi
    done

    return 0
}

#
# Return 0 if any of the elements is of value N
#
function array::any() {
    log::trace "${FUNCNAME[0]}: Checking if any element equals value"

    [[ "${#}" -lt 2 ]] && return 2

    local value="${1}"
    shift

    local -a elements=("${@}")

    for element in "${elements[@]}"; do
        if var::equals "${value}" "${element}"; then
            return 0
        fi
    done

    return 1
}

#
# Return 0 if none of the elements is of value N
#
function array::none() {
    log::trace "${FUNCNAME[0]}: Checking if no elements equal value"

    [[ "${#}" -lt 2 ]] && return 2

    local value="${1}"
    shift

    local -a elements=("${@}")

    for element in "${elements[@]}"; do
        if var::equals "${value}" "${element}"; then
            return 1
        fi
    done

    return 0
}

#
# Return 0 if all elements are of the same value
#
function array::allvalue() {
    log::trace "${FUNCNAME[0]}: Checking if all elements match predicate"

    [[ "${#}" -lt 2 ]] && return 2

    local comparison="${1}"
    shift

    local -a elements=("${@}")
    local -i offcount=0

    for element in "${elements[@]}"; do
        if ! "${comparison}" "${element}"; then
            offcount+=1
        fi
    done

    if var::eq "${offcount}" 0; then
        return 0
    fi

    return 1
}

#
# Return 0 if all elements are "true" or "0"
#
function array::alltrue() {
    log::trace "${FUNCNAME[0]}: Checking if all elements are true"

    [[ "${#}" -lt 2 ]] && return 2

    array::allvalue var::is_true "${@}"
}

#
# Return 0 if all elements are
#
function array::allfalse() {
    log::trace "${FUNCNAME[0]}: Checking if all elements are false"

    [[ "${#}" -lt 2 ]] && return 2

    array::allvalue var::is_false "${@}"
}

#
# Return 0 if all elements are none or empty string
#
function array::allnone() {
    log::trace "${FUNCNAME[0]}: Checking if all elements are none"

    [[ "${#}" -lt 2 ]] && return 2

    array::allvalue var::is_none "${@}"
}

#
# Return 0 if any elements are of the same value
#
function array::anyvalue() {
    log::trace "${FUNCNAME[0]}: Checking if any elements match predicate"

    [[ "${#}" -lt 2 ]] && return 2

    local comparison="${1}"
    shift

    local -a elements=("${@}")
    local -i offcount=0

    for element in "${elements[@]}"; do
        if "${comparison}" "${element}"; then
            offcount+=1
        fi
    done

    if var::gt "${offcount}" 0; then
        return 0
    fi

    return 1
}

#
# Return 0 if any elements are "true" or "0"
#
function array::anytrue() {
    log::trace "${FUNCNAME[0]}: Checking if any elements are true"

    [[ "${#}" -lt 2 ]] && return 2

    array::anyvalue var::is_true "${@}"
}

#
# Return 0 if any elements are
#
function array::anyfalse() {
    log::trace "${FUNCNAME[0]}: Checking if any elements are false"

    [[ "${#}" -lt 2 ]] && return 2

    array::anyvalue var::is_false "${@}"
}

#
# Return 0 if any elements are none or empty string
#
function array::anynone() {
    log::trace "${FUNCNAME[0]}: Checking if any elements are none"

    [[ "${#}" -lt 2 ]] && return 2

    array::anyvalue var::is_none "${@}"
}

################################################################################
#                                                                              #
################################################################################
