#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    TEST_DIR="$(mktemp -d)"
    export MACHINE_ID_SRC="${TEST_DIR}/machine-id"
    export MACHINE_ID_DEST="${TEST_DIR}/data/config/system/machine-id"
}

teardown() {
    rm -rf "${TEST_DIR}"
    unset MACHINE_ID_SRC MACHINE_ID_DEST
}

##
## machine_id::persist
##

@test "machine_id::persist: persists machine-id to dest" {
    echo "abc123def456abc123def456abc12300" > "${MACHINE_ID_SRC}"
    run machine_id::persist
    [ "${status}" -eq 0 ]
    [ -f "${MACHINE_ID_DEST}" ]
    [ "$(cat "${MACHINE_ID_DEST}")" = "abc123def456abc123def456abc12300" ]
}

@test "machine_id::persist: dest is read-only after persist" {
    echo "abc123def456abc123def456abc12300" > "${MACHINE_ID_SRC}"
    machine_id::persist
    local perms
    perms="$(stat -c '%a' "${MACHINE_ID_DEST}" 2>/dev/null || stat -f '%A' "${MACHINE_ID_DEST}")"
    [ "${perms}" = "444" ]
}

@test "machine_id::persist: no-ops if already persisted" {
    echo "abc123def456abc123def456abc12300" > "${MACHINE_ID_SRC}"
    mkdir -p "$(dirname "${MACHINE_ID_DEST}")"
    echo "existing" > "${MACHINE_ID_DEST}"
    run machine_id::persist
    [ "${status}" -eq 0 ]
    [ "$(cat "${MACHINE_ID_DEST}")" = "existing" ]
}

@test "machine_id::persist: no-ops if source missing" {
    run machine_id::persist
    [ "${status}" -eq 0 ]
    [ ! -f "${MACHINE_ID_DEST}" ]
}

@test "machine_id::persist: no-ops if machine-id is uninitialized" {
    echo "uninitialized" > "${MACHINE_ID_SRC}"
    run machine_id::persist
    [ "${status}" -eq 0 ]
    [ ! -f "${MACHINE_ID_DEST}" ]
}

@test "machine_id::persist: no-ops if machine-id is empty" {
    echo "" > "${MACHINE_ID_SRC}"
    run machine_id::persist
    [ "${status}" -eq 0 ]
    [ ! -f "${MACHINE_ID_DEST}" ]
}

@test "machine_id::persist: creates parent directories" {
    echo "abc123def456abc123def456abc12300" > "${MACHINE_ID_SRC}"
    run machine_id::persist
    [ "${status}" -eq 0 ]
    [ -d "$(dirname "${MACHINE_ID_DEST}")" ]
}
