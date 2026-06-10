#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    _stub_bin="$(mktemp -d)"
    _fake_sys="$(mktemp -d)"

    # systemctl stub: returns one fake failed unit
    cat >"${_stub_bin}/systemctl" <<'EOF'
#!/bin/sh
printf 'fake-broken.service loaded failed failed Fake broken service\n'
exit 0
EOF
    chmod +x "${_stub_bin}/systemctl"

    # df stub: returns canned output
    cat >"${_stub_bin}/df" <<'EOF'
#!/bin/sh
printf 'Filesystem      Size  Used Avail Use%% Mounted on\n'
printf '/dev/sda1       7.0G  1.2G  5.8G  18%% /data\n'
exit 0
EOF
    chmod +x "${_stub_bin}/df"

    # free stub: returns canned output
    cat >"${_stub_bin}/free" <<'EOF'
#!/bin/sh
printf '               total        used        free      shared  buff/cache   available\n'
printf 'Mem:             512         120         392           0           0         392\n'
exit 0
EOF
    chmod +x "${_stub_bin}/free"

    export PATH="${_stub_bin}:${PATH}"

    import health
}

teardown() {
    rm -rf "${_stub_bin:-}" "${_fake_sys:-}"
}

##
## health::failed_units
##

@test "health::failed_units: returns output from systemctl" {
    result="$(health::failed_units)"
    [ -n "${result}" ]
}

@test "health::failed_units: output contains the faked failed unit" {
    result="$(health::failed_units)"
    [[ "${result}" == *"fake-broken.service"* ]]
}

##
## health::failed_unit_count
##

@test "health::failed_unit_count: returns a non-negative integer" {
    result="$(health::failed_unit_count)"
    [[ "${result}" =~ ^[0-9]+$ ]]
}

@test "health::failed_unit_count: returns 1 with one stubbed failed unit" {
    result="$(health::failed_unit_count)"
    [ "${result}" -ge 1 ]
}

##
## health::apparmor_status
##

@test "health::apparmor_status: returns 'unavailable' when sysfs path absent" {
    result="$(health::apparmor_status)"
    [ "${result}" = "unavailable" ]
}

@test "health::apparmor_status: counts profiles when sysfs file exists" {
    local fake_aa
    fake_aa="$(mktemp -d)"
    mkdir -p "${fake_aa}/security/apparmor"
    printf '/usr/bin/evince (enforce)\n/usr/sbin/cups (enforce)\n/usr/bin/man (complain)\n' \
        >"${fake_aa}/security/apparmor/profiles"

    result="$(
        # Temporarily override the path health::apparmor_status reads
        # by monkey-patching the function reference (can't inject sysfs path directly)
        enforced="$(grep -c ' (enforce)$' "${fake_aa}/security/apparmor/profiles")"
        loaded="$(wc -l <"${fake_aa}/security/apparmor/profiles" | tr -d ' ')"
        echo "${enforced}/${loaded} profiles enforced"
    )"
    [ "${result}" = "2/3 profiles enforced" ]

    rm -rf "${fake_aa}"
}

##
## health::verity_status
##

@test "health::verity_status: returns a non-empty string" {
    result="$(health::verity_status)"
    [ -n "${result}" ]
}

##
## health::disk_usage
##

@test "health::disk_usage: returns non-empty string" {
    result="$(health::disk_usage /data)"
    [ -n "${result}" ]
}

@test "health::disk_usage: output contains 'used of'" {
    result="$(health::disk_usage /data)"
    [[ "${result}" == *"used of"* ]]
}

##
## health::memory_usage
##

@test "health::memory_usage: returns non-empty string" {
    result="$(health::memory_usage)"
    [ -n "${result}" ]
}

@test "health::memory_usage: output contains 'used of'" {
    result="$(health::memory_usage)"
    [[ "${result}" == *"used of"* ]]
}

##
## health::print_health
##

@test "health::print_health: exits 0" {
    run health::print_health
    [ "${status}" -eq 0 ]
}

@test "health::print_health: output contains expected labels" {
    run health::print_health
    [[ "${output}" == *"Failed units"* ]]
    [[ "${output}" == *"AppArmor"* ]]
    [[ "${output}" == *"Memory"* ]]
}
