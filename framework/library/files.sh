#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312,SC2329

################################################################################
# File management                                                              #
################################################################################

#
# Merge 2 list files into one
#

function files::merge_files() {
    log::trace "${FUNCNAME[0]}: Merging content of file in multiple directories"

    [[ "${#}" -lt 2 ]] && return 2

    local filename="${1}"
    shift

    local -a directories=("${@}")

    local tmpfile outfile

    tmpfile="$(mktemp -t "${filename}-XXXX")"
    outfile="$(mktemp -t "${filename}-XXXX")"

    for directory in "${directories[@]}"; do
        if [[ -e "${directory}/${filename}" ]]; then
            grep -vE '^#|^$' "${directory}/${filename}" >>"${tmpfile}"
        fi
    done

    sort -u -r <"${tmpfile}" >"${outfile}"

    rm -f "${tmpfile}" || return 1

    echo "${outfile}"

    return 0
}

################################################################################
# Append unique lines from one file into another                               #
################################################################################

#
# Append lines from src into dst, skipping blank lines, comments (#), and any
# line already present verbatim in dst.  Creates dst if it does not exist.
# Returns 1 if src is not a readable file, 2 on wrong arity.
#
function files::append_unique_lines() {
    log::trace "${FUNCNAME[0]}: appending unique lines from ${1} into ${2}"

    [[ "${#}" -ne 2 ]] && return 2

    local src="${1}" dst="${2}"

    [[ -f "${src}" ]] || return 1

    touch "${dst}"

    local added=0
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ -z "${line}" || "${line}" == \#* ]] && continue
        if ! grep -qxF "${line}" "${dst}" 2>/dev/null; then
            printf '%s\n' "${line}" >>"${dst}"
            added=$((added + 1))
        fi
    done <"${src}"

    [[ "${added}" -gt 0 ]] && log::info "${FUNCNAME[0]}: added ${added} line(s) from ${src}"
    return 0
}

################################################################################
#                                                                              #
################################################################################
