#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    _stub_bin="$(mktemp -d)"

    printf '#!/bin/sh\necho "systemd-sysext $*" >> "%s/calls.log"\nexit 0\n' "${_stub_bin}" \
        > "${_stub_bin}/systemd-sysext"
    printf '#!/bin/sh\necho "systemd-confext $*" >> "%s/calls.log"\nexit 0\n' "${_stub_bin}" \
        > "${_stub_bin}/systemd-confext"
    chmod +x "${_stub_bin}/systemd-sysext" "${_stub_bin}/systemd-confext"

    # priv::run calls "sudo boxctl-su <cmd>" when non-root; stub both to pass through
    printf '#!/bin/sh\nexec "$@"\n' > "${_stub_bin}/sudo"
    printf '#!/bin/sh\nexec "$@"\n' > "${_stub_bin}/boxctl-su"
    chmod +x "${_stub_bin}/sudo" "${_stub_bin}/boxctl-su"

    export PATH="${_stub_bin}:${PATH}"
    export _SYSEXT_DIR="$(mktemp -d)"
    export _CONFEXT_DIR="$(mktemp -d)"

    import sysext confext
}

teardown() {
    rm -rf "${_stub_bin:-}" "${_SYSEXT_DIR:-}" "${_CONFEXT_DIR:-}"
}

##
## sysext::list
##

@test "sysext::list: returns 0" {
    run sysext::list
    [ "${status}" -eq 0 ]
}

@test "sysext::list: calls systemd-sysext list" {
    sysext::list
    grep -q "list" "${_stub_bin}/calls.log"
}

##
## sysext::status
##

@test "sysext::status: returns 0" {
    run sysext::status
    [ "${status}" -eq 0 ]
}

@test "sysext::status: calls systemd-sysext status" {
    sysext::status
    grep -q "status" "${_stub_bin}/calls.log"
}

##
## sysext::merge
##

@test "sysext::merge: returns 0" {
    run sysext::merge
    [ "${status}" -eq 0 ]
}

@test "sysext::merge: calls systemd-sysext merge" {
    sysext::merge
    grep -q "merge" "${_stub_bin}/calls.log"
}

##
## sysext::unmerge
##

@test "sysext::unmerge: returns 0" {
    run sysext::unmerge
    [ "${status}" -eq 0 ]
}

@test "sysext::unmerge: calls systemd-sysext unmerge" {
    sysext::unmerge
    grep -q "unmerge" "${_stub_bin}/calls.log"
}

##
## sysext::refresh
##

@test "sysext::refresh: returns 0" {
    run sysext::refresh
    [ "${status}" -eq 0 ]
}

@test "sysext::refresh: calls systemd-sysext refresh" {
    sysext::refresh
    grep -q "refresh" "${_stub_bin}/calls.log"
}

##
## sysext::storage_dir
##

@test "sysext::storage_dir: returns configured dir" {
    result="$(sysext::storage_dir)"
    [ "${result}" = "${_SYSEXT_DIR}" ]
}

##
## confext::list
##

@test "confext::list: returns 0" {
    run confext::list
    [ "${status}" -eq 0 ]
}

##
## confext::storage_dir
##

@test "confext::storage_dir: returns configured dir" {
    result="$(confext::storage_dir)"
    [ "${result}" = "${_CONFEXT_DIR}" ]
}
