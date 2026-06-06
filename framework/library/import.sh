#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

################################################################################
# Framework variables                                                          #
################################################################################

declare FRAMEWORK_LIB_PATH="${FRAMEWORK_LIB_PATH:-}"

export -a FRAMEWORK_LIB_SOURCES=()

################################################################################
# Module list                                                                  #
################################################################################

export -a FRAMEWORK_INIT_MODULES=(
    array
    arguments
    debug
    depends
    fs
    fw
    interact
    net
    proc
    string
    system
    time
    var
)

################################################################################
# Import                                                                       #
################################################################################

function core::is_sourceable() {
    [[ "${#}" -ne 1 ]] && return 2

    local file filetype

    file="${1}"
    shift

    if [[ ! -e "${file}" ]]; then
        return 1
    fi

    if ! fullfile="$(realpath "${file}")"; then
        return 1
    fi

    filetype="$(
        command file "${fullfile}" |
            awk -F ': ' '{ print $2 }' |
            sed -e 's/\ \ /\ /g' ||
            true
    )"

    local -i is_sourceable

    case "${filetype}" in

        *"framework script"* | *"toolset script"*)
            is_sourceable=0
            ;;

        *"sh script"*)
            is_sourceable=0
            ;;

        *"Bourne-Again shell"*)
            is_sourceable=0
            ;;

        *"POSIX shell"*)
            is_sourceable=0
            ;;

        *"ASCII text"*)
            is_sourceable=0
            ;;

        *"Unicode text"*)
            is_sourceable=0
            ;;

        *"UTF-8 text"*)
            is_sourceable=0
            ;;

        *"fifo (named pipe)")
            is_sourceable=0
            ;;

        *)
            is_sourceable=1
            ;;
    esac

    return "${is_sourceable}"
}

function core::find_library() {
    local library input

    input="${1}"
    shift

    for filename in "${input}.sh" "${input}"; do

        if [[ -f "${FRAMEWORK_LIB_PATH}/${filename}" ]]; then
            library="${FRAMEWORK_LIB_PATH}/${filename}"
            break

        elif [[ -f "${filename}" ]]; then
            library="${filename}"
            break

        elif command -v "${filename}" >/dev/null 2>&1; then
            library="$(command -v "${filename}")"
            break
        fi
    done

    library="$(realpath -q "${library}" || true)"

    if [[ -n "${library}" ]] && core::is_sourceable "${library}"; then
        echo -ne "${library}"
        return 0
    fi

    return 1
}

function core::import() {
    [[ "${#}" -lt 1 ]] && return 2

    local source_file=""
    local exitcode=0

    local -ra input=("${@}")

    for file in "${input[@]}"; do

        if [[ "${file}" =~ :: ]]; then
            file="${file//::/\/}"
        fi

        if ! source_file="$(core::find_library "${file}")"; then
            echo "ERROR: ${FUNCNAME[0]}: Failed to find file for import: ${file}" >&2
            exitcode=1
            continue
        fi

        local _loaded _already=0
        for _loaded in "${FRAMEWORK_LIB_SOURCES[@]}"; do
            [[ "${_loaded}" == "${source_file}" ]] && {
                _already=1
                break
            }
        done
        [[ "${_already}" -eq 1 ]] && continue

        FRAMEWORK_LIB_SOURCES+=("${source_file}")

        # shellcheck source=/dev/null
        if ! source "${source_file}"; then
            echo "ERROR: ${FUNCNAME[0]}: Failed to source ${source_file}" >&2
            exitcode=1
            continue
        fi
    done

    return "${exitcode}"
}

function import() { core::import "${@}"; }
