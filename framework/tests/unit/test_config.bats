#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    import config
    CONFIG_TMPDIR="$(mktemp -d)"
    export CONFIG_DIR="${CONFIG_TMPDIR}"
}

teardown() {
    rm -rf "${CONFIG_TMPDIR:-}"
}

##
## config::ensure_writable
##

@test "config::ensure_writable: returns 0 when CONFIG_DIR exists and is writable" {
    run config::ensure_writable
    [ "${status}" -eq 0 ]
}

@test "config::ensure_writable: returns 1 when CONFIG_DIR does not exist" {
    export CONFIG_DIR="/tmp/nonexistent_labctl_config_xyz"
    run config::ensure_writable
    [ "${status}" -eq 1 ]
}

##
## config::write / config::read
##

@test "config::write: returns 0" {
    run config::write "hostname" "testdevice"
    [ "${status}" -eq 0 ]
}

@test "config::read: retrieves a value that was written" {
    config::write "hostname" "testdevice"
    run config::read "hostname"
    [ "${status}" -eq 0 ]
    [ "${output}" = "testdevice" ]
}

@test "config::read: returns 1 for a missing key" {
    run config::read "nonexistent_key"
    [ "${status}" -eq 1 ]
}

@test "config::read: returns 2 with no arguments" {
    run config::read
    [ "${status}" -eq 2 ]
}

@test "config::write: returns 2 with wrong argument count" {
    run config::write "onlyonearg"
    [ "${status}" -eq 2 ]
}

@test "config::write and config::read: round-trip preserves value" {
    config::write "testkey" "hello world"
    run config::read "testkey"
    [ "${status}" -eq 0 ]
    [ "${output}" = "hello world" ]
}

@test "config::write: supports nested keys (subdirectory)" {
    run config::write "network/ssid" "mywifi"
    [ "${status}" -eq 0 ]
    run config::read "network/ssid"
    [ "${status}" -eq 0 ]
    [ "${output}" = "mywifi" ]
}

##
## config::delete
##

@test "config::delete: removes a key" {
    config::write "todelete" "value"
    config::delete "todelete"
    run config::read "todelete"
    [ "${status}" -eq 1 ]
}

@test "config::delete: returns 0 when key does not exist" {
    run config::delete "nonexistent"
    [ "${status}" -eq 0 ]
}

@test "config::delete: returns 2 with no arguments" {
    run config::delete
    [ "${status}" -eq 2 ]
}

##
## config::list
##

@test "config::list: returns 0 and lists written keys" {
    config::write "alpha" "1"
    config::write "beta" "2"
    run config::list
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "alpha" ]]
    [[ "${output}" =~ "beta" ]]
}

@test "config::list: returns 1 when CONFIG_DIR does not exist" {
    export CONFIG_DIR="/tmp/nonexistent_labctl_xyz"
    run config::list
    [ "${status}" -eq 1 ]
}
