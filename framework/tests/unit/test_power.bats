#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    import config power

    # Temp config dir
    CONFIG_TMPDIR="$(mktemp -d)"
    export CONFIG_DIR="${CONFIG_TMPDIR}"

    # Synthetic sysfs trees
    POWER_SYSFS_TMPDIR="$(mktemp -d)"

    # cpufreq: one policy dir (like Pi Zero 2W with shared policy)
    mkdir -p "${POWER_SYSFS_TMPDIR}/cpufreq/policy0"
    printf 'schedutil\n' > "${POWER_SYSFS_TMPDIR}/cpufreq/policy0/scaling_governor"
    export POWER_CPUFREQ_PATH="${POWER_SYSFS_TMPDIR}/cpufreq"

    # USB: two fake device power dirs
    mkdir -p "${POWER_SYSFS_TMPDIR}/usb/1-1/power"
    printf 'auto\n'  > "${POWER_SYSFS_TMPDIR}/usb/1-1/power/control"
    printf '2000\n'  > "${POWER_SYSFS_TMPDIR}/usb/1-1/power/autosuspend_delay_ms"
    mkdir -p "${POWER_SYSFS_TMPDIR}/usb/1-2/power"
    printf 'auto\n'  > "${POWER_SYSFS_TMPDIR}/usb/1-2/power/control"
    printf '2000\n'  > "${POWER_SYSFS_TMPDIR}/usb/1-2/power/autosuspend_delay_ms"
    export POWER_USB_PATH="${POWER_SYSFS_TMPDIR}/usb"
}

teardown() {
    rm -rf "${CONFIG_TMPDIR:-}" "${POWER_SYSFS_TMPDIR:-}"
}

##
## power::is_valid_profile
##

@test "power::is_valid_profile: returns 0 for performance" {
    run power::is_valid_profile "performance"
    [ "${status}" -eq 0 ]
}

@test "power::is_valid_profile: returns 0 for balanced" {
    run power::is_valid_profile "balanced"
    [ "${status}" -eq 0 ]
}

@test "power::is_valid_profile: returns 0 for saver" {
    run power::is_valid_profile "saver"
    [ "${status}" -eq 0 ]
}

@test "power::is_valid_profile: returns 1 for unknown name" {
    run power::is_valid_profile "turbo"
    [ "${status}" -eq 1 ]
}

@test "power::is_valid_profile: returns 2 with no arguments" {
    run power::is_valid_profile
    [ "${status}" -eq 2 ]
}

##
## power::list_profiles
##

@test "power::list_profiles: outputs all three profiles" {
    run power::list_profiles
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "performance" ]]
    [[ "${output}" =~ "balanced" ]]
    [[ "${output}" =~ "saver" ]]
}

##
## power::get_profile
##

@test "power::get_profile: returns default when no config set" {
    run power::get_profile
    [ "${status}" -eq 0 ]
    [ "${output}" = "balanced" ]
}

@test "power::get_profile: returns value written to config" {
    config::write "power/profile" "saver"
    run power::get_profile
    [ "${status}" -eq 0 ]
    [ "${output}" = "saver" ]
}

##
## power::apply_profile
##

@test "power::apply_profile: returns 2 with no arguments" {
    run power::apply_profile
    [ "${status}" -eq 2 ]
}

@test "power::apply_profile: returns 1 for unknown profile" {
    run power::apply_profile "turbo"
    [ "${status}" -eq 1 ]
}

@test "power::apply_profile: performance sets governor to performance" {
    power::apply_profile "performance"
    run cat "${POWER_CPUFREQ_PATH}/policy0/scaling_governor"
    [ "${output}" = "performance" ]
}

@test "power::apply_profile: performance sets USB control to on" {
    power::apply_profile "performance"
    run cat "${POWER_USB_PATH}/1-1/power/control"
    [ "${output}" = "on" ]
}

@test "power::apply_profile: balanced sets governor to schedutil" {
    power::apply_profile "balanced"
    run cat "${POWER_CPUFREQ_PATH}/policy0/scaling_governor"
    [ "${output}" = "schedutil" ]
}

@test "power::apply_profile: balanced sets USB autosuspend to 2000ms" {
    power::apply_profile "balanced"
    run cat "${POWER_USB_PATH}/1-1/power/autosuspend_delay_ms"
    [ "${output}" = "2000" ]
}

@test "power::apply_profile: saver sets governor to powersave" {
    power::apply_profile "saver"
    run cat "${POWER_CPUFREQ_PATH}/policy0/scaling_governor"
    [ "${output}" = "powersave" ]
}

@test "power::apply_profile: saver sets USB autosuspend to 500ms" {
    power::apply_profile "saver"
    run cat "${POWER_USB_PATH}/1-1/power/autosuspend_delay_ms"
    [ "${output}" = "500" ]
}

@test "power::apply_profile: applies to multiple USB devices" {
    power::apply_profile "saver"
    run cat "${POWER_USB_PATH}/1-2/power/autosuspend_delay_ms"
    [ "${output}" = "500" ]
}

@test "power::apply_profile: no-ops cleanly when no USB devices present" {
    export POWER_USB_PATH="${POWER_SYSFS_TMPDIR}/usb_empty"
    mkdir -p "${POWER_SYSFS_TMPDIR}/usb_empty"
    run power::apply_profile "saver"
    [ "${status}" -eq 0 ]
}
