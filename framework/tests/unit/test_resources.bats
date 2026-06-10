#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    _stub_bin="$(mktemp -d)"
    _fake_sys="$(mktemp -d)"

    export _RESOURCES_FILE
    _RESOURCES_FILE="$(mktemp)"

    cat >"${_RESOURCES_FILE}" <<'EOF'
{
  "total_memory_mb": 512,
  "total_storage_mb": 7000,
  "cpu_cores": 4,
  "baseline_memory_mb": 120,
  "measured_at": "2026-06-07T10:00:00Z"
}
EOF

    # Fake /proc/meminfo and CPU sysfs (macOS has neither)
    export _PROC_MEMINFO="${_fake_sys}/meminfo"
    printf 'MemTotal:         524288 kB\nMemFree:          262144 kB\nMemAvailable:     393216 kB\n' \
        >"${_PROC_MEMINFO}"

    export _CPU_ONLINE_PATH="${_fake_sys}/cpu_online"
    printf '0-3\n' >"${_CPU_ONLINE_PATH}"

    # df stub: returns canned output regardless of path argument
    cat >"${_stub_bin}/df" <<'EOF'
#!/bin/sh
printf 'Filesystem      1M-blocks  Used Available Use%% Mounted on\n'
printf '/dev/mmcblk0p4       7168  1024      6144  15%% /data\n'
EOF
    chmod +x "${_stub_bin}/df"
    export _STORAGE_PATH="${_fake_sys}/data"
    mkdir -p "${_fake_sys}/data"
    export PATH="${_stub_bin}:${PATH}"

    import resources
}

teardown() {
    rm -rf "${_stub_bin:-}" "${_fake_sys:-}" "${_RESOURCES_FILE:-}"
}

##
## resources::get
##

@test "resources::get: returns 2 with no arguments" {
    run resources::get
    [ "${status}" -eq 2 ]
}

@test "resources::get: returns total_memory_mb" {
    result="$(resources::get total_memory_mb)"
    [ "${result}" = "512" ]
}

@test "resources::get: returns cpu_cores" {
    result="$(resources::get cpu_cores)"
    [ "${result}" = "4" ]
}

@test "resources::get: returns empty for missing key" {
    result="$(resources::get nonexistent_key)"
    [ -z "${result}" ]
}

@test "resources::get: returns 1 when file missing" {
    export _RESOURCES_FILE="/nonexistent/resources.json"
    run resources::get total_memory_mb
    [ "${status}" -eq 1 ]
}

##
## resources::available_memory
##

@test "resources::available_memory: returns total minus baseline" {
    result="$(resources::available_memory)"
    [ "${result}" = "392" ]
}

@test "resources::available_memory: returns 1 when file missing" {
    export _RESOURCES_FILE="/nonexistent/resources.json"
    run resources::available_memory
    [ "${status}" -eq 1 ]
}

##
## resources::cpu_cores
##

@test "resources::cpu_cores: awk parses range format to core count" {
    result="$(awk -F- '{if (NF==2) print $2-$1+1; else print 1}' <<<"0-3")"
    [ "${result}" = "4" ]
}

@test "resources::cpu_cores: awk handles single CPU format" {
    result="$(awk -F- '{if (NF==2) print $2-$1+1; else print 1}' <<<"0")"
    [ "${result}" = "1" ]
}

@test "resources::cpu_cores: returns 4 from fake sysfs file" {
    result="$(resources::cpu_cores)"
    [ "${result}" = "4" ]
}

##
## resources::total_memory_mb
##

@test "resources::total_memory_mb: returns correct value from fake meminfo" {
    # 524288 kB / 1024 = 512 MB
    result="$(resources::total_memory_mb)"
    [ "${result}" = "512" ]
}

##
## resources::used_memory_mb
##

@test "resources::used_memory_mb: returns correct value from fake meminfo" {
    # (524288 - 393216) / 1024 = 128 MB used
    result="$(resources::used_memory_mb)"
    [ "${result}" = "128" ]
}

##
## resources::snapshot
##

@test "resources::snapshot: writes valid JSON to _RESOURCES_FILE" {
    local tmpfile
    tmpfile="$(mktemp)"
    export _RESOURCES_FILE="${tmpfile}"

    run resources::snapshot
    [ "${status}" -eq 0 ]
    [ -s "${tmpfile}" ]
    jq . "${tmpfile}" >/dev/null

    rm -f "${tmpfile}"
}

@test "resources::snapshot: JSON contains all expected keys" {
    local tmpfile
    tmpfile="$(mktemp)"
    export _RESOURCES_FILE="${tmpfile}"

    resources::snapshot

    jq -e '.total_memory_mb' "${tmpfile}" >/dev/null
    jq -e '.cpu_cores' "${tmpfile}" >/dev/null
    jq -e '.baseline_memory_mb' "${tmpfile}" >/dev/null
    jq -e '.total_storage_mb' "${tmpfile}" >/dev/null
    jq -e '.measured_at' "${tmpfile}" >/dev/null

    rm -f "${tmpfile}"
}

@test "resources::snapshot: creates parent directory if missing" {
    local tmpdir tmpfile
    tmpdir="$(mktemp -d)"
    tmpfile="${tmpdir}/subdir/resources.json"
    export _RESOURCES_FILE="${tmpfile}"

    run resources::snapshot
    [ "${status}" -eq 0 ]
    [ -f "${tmpfile}" ]

    rm -rf "${tmpdir}"
}
