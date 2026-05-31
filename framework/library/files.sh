#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

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
#                                                                              #
################################################################################
