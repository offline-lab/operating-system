#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    _stub_bin="$(mktemp -d)"
    export _RESOURCES_FILE="$(mktemp)"

    cat > "${_RESOURCES_FILE}" <<'EOF'
{
  "total_memory_mb": 512,
  "total_storage_mb": 7000,
  "cpu_cores": 4,
  "baseline_memory_mb": 120,
  "baseline_cpu_percent": 8,
  "measured_at": "2026-06-07T10:00:00Z"
}
EOF

    printf '#!/bin/sh\ndf "$@"\n' > "${_stub_bin}/df"
    chmod +x "${_stub_bin}/df"
    export PATH="${_stub_bin}:${PATH}"

    import resources
}

teardown() {
    rm -rf "${_stub_bin:-}" "${_RESOURCES_FILE:-}"
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
