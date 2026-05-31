#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    import cache
    CACHE_TMPDIR="$(mktemp -d)"
    cache::setup "${CACHE_TMPDIR}"
}

teardown() {
    rm -rf "${CACHE_TMPDIR:-}"
}

##
## cache::setup
##

@test "cache::setup: returns 0" {
    run cache::setup "${CACHE_TMPDIR}"
    [ "${status}" -eq 0 ]
}

@test "cache::setup: creates the cache directory" {
    local dir
    dir="$(mktemp -d)"
    rm -rf "${dir}"
    cache::setup "${dir}"
    [ -d "${dir}" ]
    rm -rf "${dir}"
}

@test "cache::setup: sets cachedir variable" {
    [ -n "${cachedir}" ]
}

##
## cache::set / cache::get
##

@test "cache::set: writes a value and returns 0" {
    run cache::set "testkey" "testvalue"
    [ "${status}" -eq 0 ]
}

@test "cache::get: retrieves a value that was set" {
    cache::set "mykey" "myvalue"
    run cache::get "mykey"
    [ "${status}" -eq 0 ]
    [ "${output}" = "myvalue" ]
}

@test "cache::get: returns 1 for a missing key" {
    run cache::get "nonexistent_key_xyz"
    [ "${status}" -eq 1 ]
}

@test "cache::set and cache::get: round-trip preserves value" {
    local value="hello world 123"
    cache::set "roundtrip" "${value}"
    run cache::get "roundtrip"
    [ "${status}" -eq 0 ]
    [ "${output}" = "${value}" ]
}

##
## cache::flush
##

@test "cache::flush: removes a cached key" {
    cache::set "flushme" "value"
    cache::flush "flushme"
    run cache::get "flushme"
    [ "${status}" -eq 1 ]
}

##
## cache::flushall
##

@test "cache::flushall: removes all cached keys" {
    cache::set "key1" "val1"
    cache::set "key2" "val2"
    cache::flushall
    run cache::get "key1"
    [ "${status}" -eq 1 ]
}

##
## arity checks
##

@test "cache::exists: returns 2 with no arguments" {
    run cache::exists
    [ "${status}" -eq 2 ]
}

@test "cache::get: returns 2 with no arguments" {
    run cache::get
    [ "${status}" -eq 2 ]
}

@test "cache::set: returns 2 with no arguments" {
    run cache::set
    [ "${status}" -eq 2 ]
}

@test "cache::set: returns 2 with only one argument" {
    run cache::set onlykey
    [ "${status}" -eq 2 ]
}

@test "cache::flush: returns 2 with no arguments" {
    run cache::flush
    [ "${status}" -eq 2 ]
}
