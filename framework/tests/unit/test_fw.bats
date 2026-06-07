#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    _stub_bin="$(mktemp -d)"

    # Stub nft — record calls for assertion, always succeed
    printf '#!/bin/sh\necho "$@" >> "%s/nft.log"\nexit 0\n' "${_stub_bin}" \
        > "${_stub_bin}/nft"
    chmod +x "${_stub_bin}/nft"

    export PATH="${_stub_bin}:${PATH}"

    export _FW_APP_DIR="$(mktemp -d)"
    export _FW_STATE="${_stub_bin}/fw.state"
    export _FW_STATIC="${_stub_bin}/rules.fw"

    printf 'table inet filter { chain input { type filter hook input priority 0; policy drop; } }\n' \
        > "${_FW_STATIC}"

    import fw
}

teardown() {
    rm -rf "${_stub_bin:-}" "${_FW_APP_DIR:-}"
}

##
## fw::flush
##

@test "fw::flush: removes state file" {
    touch "${_FW_STATE}"
    fw::flush
    [[ ! -f "${_FW_STATE}" ]]
}

@test "fw::flush: returns 0" {
    run fw::flush
    [ "${status}" -eq 0 ]
}

##
## fw::down
##

@test "fw::down: removes state file" {
    touch "${_FW_STATE}"
    fw::down
    [[ ! -f "${_FW_STATE}" ]]
}

##
## fw::up
##

@test "fw::up: creates state file" {
    fw::up
    [[ -f "${_FW_STATE}" ]]
}

@test "fw::up: returns 0" {
    run fw::up
    [ "${status}" -eq 0 ]
}

##
## fw::reset
##

@test "fw::reset: creates state file" {
    fw::reset
    [[ -f "${_FW_STATE}" ]]
}

@test "fw::reset: returns 0" {
    run fw::reset
    [ "${status}" -eq 0 ]
}

##
## fw::init
##

@test "fw::init: calls fw::up when state file absent" {
    [[ ! -f "${_FW_STATE}" ]]
    fw::init
    [[ -f "${_FW_STATE}" ]]
}

@test "fw::init: no-op when state file present" {
    touch "${_FW_STATE}"
    run fw::init
    [ "${status}" -eq 0 ]
}

##
## fw::app_allow
##

@test "fw::app_allow: returns 2 with wrong arity" {
    run fw::app_allow myapp tcp
    [ "${status}" -eq 2 ]
}

@test "fw::app_allow: creates fragment file with correct rule" {
    fw::app_allow myapp tcp 8080
    grep -qxF -- "add rule inet filter input tcp dport 8080 accept" "${_FW_APP_DIR}/myapp.rules"
}

@test "fw::app_allow: deduplicates identical rule" {
    fw::app_allow myapp tcp 8080
    fw::app_allow myapp tcp 8080
    local count
    count="$(grep -cF "dport 8080" "${_FW_APP_DIR}/myapp.rules")"
    [ "${count}" -eq 1 ]
}

@test "fw::app_allow: allows multiple ports in same app fragment" {
    fw::app_allow myapp tcp 8080
    fw::app_allow myapp tcp 8443
    grep -qxF -- "add rule inet filter input tcp dport 8080 accept" "${_FW_APP_DIR}/myapp.rules"
    grep -qxF -- "add rule inet filter input tcp dport 8443 accept" "${_FW_APP_DIR}/myapp.rules"
}

@test "fw::app_allow: applies rule immediately when firewall is up" {
    touch "${_FW_STATE}"
    fw::app_allow myapp tcp 9000
    grep -q "add rule inet filter input tcp dport 9000 accept" "${_stub_bin}/nft.log"
}

@test "fw::app_allow: does not call nft add rule when firewall is down" {
    rm -f "${_FW_STATE}" "${_stub_bin}/nft.log"
    fw::app_allow myapp tcp 9001
    # nft may be called for depends check but not for add rule
    ! grep -q "add rule" "${_stub_bin}/nft.log" 2>/dev/null
}

##
## fw::app_remove
##

@test "fw::app_remove: returns 2 with wrong arity" {
    run fw::app_remove
    [ "${status}" -eq 2 ]
}

@test "fw::app_remove: deletes the app fragment" {
    fw::app_allow myapp tcp 8080
    [[ -f "${_FW_APP_DIR}/myapp.rules" ]]
    fw::app_remove myapp
    [[ ! -f "${_FW_APP_DIR}/myapp.rules" ]]
}

@test "fw::app_remove: returns 0 when fragment does not exist" {
    run fw::app_remove nonexistent
    [ "${status}" -eq 0 ]
}

##
## fw::_load_apps
##

@test "fw::_load_apps: returns 0 when app dir does not exist" {
    export _FW_APP_DIR="/tmp/nonexistent_fw_dir_xyz"
    run fw::_load_apps
    [ "${status}" -eq 0 ]
}

@test "fw::_load_apps: returns 0 when app dir is empty" {
    run fw::_load_apps
    [ "${status}" -eq 0 ]
}
