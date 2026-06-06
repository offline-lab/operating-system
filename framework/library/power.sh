#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

# Runtime power profile management for boxctl.
# All functions require the framework to be sourced before this file.
# Requires: config module, systemctl (for set_profile), root (for apply_profile)

POWER_CONFIG_KEY="power/profile"
POWER_DEFAULT_PROFILE="balanced"

# Overridable in tests
POWER_CPUFREQ_PATH="${POWER_CPUFREQ_PATH:-/sys/devices/system/cpu/cpufreq}"
POWER_USB_PATH="${POWER_USB_PATH:-/sys/bus/usb/devices}"

function power::list_profiles() {
    log::trace "${FUNCNAME[0]}: Listing available profiles"
    printf '%s\n' performance balanced saver
}

function power::is_valid_profile() {
    log::trace "${FUNCNAME[0]}: Validating profile: ${1:-}"
    [[ "${#}" -ne 1 ]] && return 2
    case "${1}" in
        performance | balanced | saver) return 0 ;;
        *) return 1 ;;
    esac
}

function power::get_profile() {
    log::trace "${FUNCNAME[0]}: Reading current profile"
    config::read "${POWER_CONFIG_KEY}" 2>/dev/null || printf '%s\n' "${POWER_DEFAULT_PROFILE}"
}

function power::_write_sysfs() {
    log::trace "${FUNCNAME[0]}: ${1} <- ${2}"
    [[ "${#}" -ne 2 ]] && return 2
    [[ -f "${1}" ]] || return 0
    printf '%s\n' "${2}" >"${1}"
}

function power::_set_cpufreq_governor() {
    log::trace "${FUNCNAME[0]}: Setting governor to ${1}"
    [[ "${#}" -ne 1 ]] && return 2
    local governor="${1}"
    local policy
    for policy in "${POWER_CPUFREQ_PATH}"/policy*/scaling_governor; do
        power::_write_sysfs "${policy}" "${governor}"
    done
}

function power::_set_usb_autosuspend() {
    log::trace "${FUNCNAME[0]}: control=${1} delay=${2}ms"
    [[ "${#}" -ne 2 ]] && return 2
    local control="${1}"
    local delay_ms="${2}"
    local dev
    for dev in "${POWER_USB_PATH}"/*/power/control; do
        power::_write_sysfs "${dev}" "${control}"
        power::_write_sysfs "${dev%/control}/autosuspend_delay_ms" "${delay_ms}"
    done
}

# Apply the named profile to the running kernel — requires root.
# Called by power-profile.service on boot and by boxctl power apply.
function power::apply_profile() {
    log::trace "${FUNCNAME[0]}: Applying profile: ${1:-}"
    [[ "${#}" -ne 1 ]] && return 2
    local name="${1}"

    power::is_valid_profile "${name}" || {
        log::error "${FUNCNAME[0]}: Unknown profile: ${name}"
        return 1
    }

    case "${name}" in
        performance)
            power::_set_cpufreq_governor "performance"
            power::_set_usb_autosuspend "on" "-1"
            ;;
        balanced)
            power::_set_cpufreq_governor "schedutil"
            power::_set_usb_autosuspend "auto" "2000"
            ;;
        saver)
            power::_set_cpufreq_governor "powersave"
            power::_set_usb_autosuspend "auto" "500"
            ;;
        *)
            return 1
            ;;
    esac

    log::info "${FUNCNAME[0]}: profile active: ${name}"
}

# Persist the profile and trigger the service to apply it.
function power::set_profile() {
    log::trace "${FUNCNAME[0]}: Setting profile: ${1:-}"
    [[ "${#}" -ne 1 ]] && return 2
    local name="${1}"

    power::is_valid_profile "${name}" || {
        log::error "${FUNCNAME[0]}: Unknown profile: ${name}"
        return 1
    }

    config::write "${POWER_CONFIG_KEY}" "${name}" || return 1
    depends::check::silent systemctl || return 1
    priv::run systemctl restart power-profile.service
}
