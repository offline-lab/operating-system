#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

# zram swap management.
# Requires: zramctl, mkswap, swapon, swapoff, modprobe (all privileged).

ZRAM_FRACTION="${ZRAM_FRACTION:-1/2}"
ZRAM_ALGORITHM="${ZRAM_ALGORITHM:-lz4}"
ZRAM_COMP_FACTOR="${ZRAM_COMP_FACTOR:-}"
ZRAM_FIXED_SIZE="${ZRAM_FIXED_SIZE:-}"

################################################################################
# zram::_calc — evaluate a floating-point arithmetic expression via awk        #
################################################################################

function zram::_calc() {
    log::trace "${FUNCNAME[0]}: ${*}"
    [[ "${#}" -eq 0 ]] && return 2
    local precision=0
    var::matches "${1}" '^[[:digit:]]+$' && { precision="${1}" && shift; }
    LC_NUMERIC=C awk "BEGIN{printf \"%.${precision}f\", ${*}}"
}

################################################################################
# zram::_comp_factor — default compression ratio for given algorithm           #
################################################################################

function zram::_comp_factor() {
    log::trace "${FUNCNAME[0]}: ${ZRAM_ALGORITHM}"
    if [[ -n "${ZRAM_COMP_FACTOR}" ]]; then
        printf '%s\n' "${ZRAM_COMP_FACTOR}"
        return 0
    fi
    case "${ZRAM_ALGORITHM}" in
        lzo* | zstd) printf '3\n' ;;
        lz4) printf '2.5\n' ;;
        *) printf '2\n' ;;
    esac
}

################################################################################
# zram::_remove_device — reset a single zram block device                     #
################################################################################

function zram::_remove_device() {
    log::trace "${FUNCNAME[0]}: removing ${1}"
    [[ "${#}" -ne 1 ]] && return 2
    local dev="${1}"
    shift

    if ! fs::is_blockdev "${dev}"; then
        log::error "${FUNCNAME[0]}: ${dev} is not a block device"
        return 1
    fi

    local i
    for i in 1 2 3; do
        sleep "$(zram::_calc 2 "0.1 * ${i}")"
        zramctl -r "${dev}" 2>/dev/null || true
        fs::is_blockdev "${dev}" || return 0
    done

    log::error "${FUNCNAME[0]}: could not remove ${dev} after 3 attempts"
    return 1
}

################################################################################
# zram::start — load module, allocate device, mkswap + swapon                 #
################################################################################

function zram::start() {
    log::trace "${FUNCNAME[0]}: starting zram swap"

    depends::check::silent zramctl || return 1
    depends::check::silent mkswap || return 1
    depends::check::silent swapon || return 1

    if grep -q zram /proc/swaps 2>/dev/null; then
        log::error "${FUNCNAME[0]}: zram swap already active"
        return 1
    fi

    if ! modprobe zram 2>/dev/null; then
        log::error "${FUNCNAME[0]}: failed to load zram module"
        return 1
    fi

    local mem comp_factor
    comp_factor="$(zram::_comp_factor)"

    if [[ -n "${ZRAM_FIXED_SIZE}" ]]; then
        if ! var::matches "${ZRAM_FIXED_SIZE}" '^[[:digit:]]+(\.[[:digit:]]+)?(G|M)$'; then
            log::error "${FUNCNAME[0]}: invalid ZRAM_FIXED_SIZE '${ZRAM_FIXED_SIZE}'"
            return 1
        fi
        mem="${ZRAM_FIXED_SIZE}"
    else
        local total_kb
        total_kb="$(awk '/MemTotal/{print $2}' /proc/meminfo)"
        mem="$(zram::_calc "${total_kb} * ${comp_factor} * ${ZRAM_FRACTION} * 1024")"
    fi

    local device='' i
    for i in 1 2 3; do
        sleep "$(zram::_calc 2 "0.1 * ${i}")"
        device="$(zramctl -f -s "${mem}" -a "${ZRAM_ALGORITHM}" 2>/dev/null)" || true
        fs::is_blockdev "${device}" && break
    done

    if ! fs::is_blockdev "${device}"; then
        log::error "${FUNCNAME[0]}: failed to allocate zram device"
        return 1
    fi

    trap 'zram::_remove_device "${device}"' EXIT
    mkswap "${device}"
    swapon -d -p 15 "${device}"
    trap - EXIT

    log::info "${FUNCNAME[0]}: swap active on ${device} (${mem} bytes, ${ZRAM_ALGORITHM})"
}

################################################################################
# zram::stop — swapoff + remove all zram devices                               #
################################################################################

function zram::stop() {
    log::trace "${FUNCNAME[0]}: stopping zram swap"

    depends::check::silent swapoff || return 1

    if ! grep -q zram /proc/swaps 2>/dev/null; then
        log::error "${FUNCNAME[0]}: no active zram swaps"
        return 1
    fi

    local ret=0 dev
    while read -r dev _; do
        swapoff "${dev}" || {
            log::error "${FUNCNAME[0]}: swapoff ${dev} failed"
            ret=1
            continue
        }
        zram::_remove_device "${dev}" || ret=1
    done < <(awk '/zram/ {print $1, $0}' /proc/swaps)

    return "${ret}"
}
