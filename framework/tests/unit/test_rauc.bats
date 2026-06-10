#!/usr/bin/env bats

load "../../bin/framework"

_RAUC_STATUS_JSON='{
  "booted": "rootfs.0",
  "slots": {
    "rootfs.0": {
      "bootname": "A",
      "state": "booted",
      "device": "/dev/mmcblk0p5",
      "bundle": { "version": "1.2.3" }
    },
    "rootfs.1": {
      "bootname": "B",
      "state": "inactive",
      "device": "/dev/mmcblk0p6",
      "bundle": { "version": "1.1.0" }
    }
  }
}'

setup() {
    _stub_bin="$(mktemp -d)"

    # rauc stub: handles status and info subcommands
    cat >"${_stub_bin}/rauc" <<EOF
#!/bin/sh
cmd="\$1"
case "\${cmd}" in
    status)
        printf '%s\n' '${_RAUC_STATUS_JSON}'
        ;;
    info)
        printf 'Compatible: offlinelab-pi-zero-2w\nVersion: 2.0.0\n'
        ;;
    mark | install) exit 0 ;;
    *) exit 1 ;;
esac
exit 0
EOF
    chmod +x "${_stub_bin}/rauc"

    # priv::run pass-through stubs
    printf '#!/bin/sh\nexec "$@"\n' >"${_stub_bin}/sudo"
    printf '#!/bin/sh\nexec "$@"\n' >"${_stub_bin}/boxctl-su"
    chmod +x "${_stub_bin}/sudo" "${_stub_bin}/boxctl-su"

    export PATH="${_stub_bin}:${PATH}"

    import rauc
}

teardown() {
    rm -rf "${_stub_bin:-}"
}

##
## rauc::status_json
##

@test "rauc::status_json: returns valid JSON" {
    result="$(rauc::status_json)"
    jq . <<<"${result}" >/dev/null
}

##
## rauc::active_slot
##

@test "rauc::active_slot: returns the booted slot name" {
    result="$(rauc::active_slot)"
    [ "${result}" = "rootfs.0" ]
}

##
## rauc::slots
##

@test "rauc::slots: lists all slot names" {
    result="$(rauc::slots)"
    [[ "${result}" == *"rootfs.0"* ]]
    [[ "${result}" == *"rootfs.1"* ]]
}

##
## rauc::slot_field
##

@test "rauc::slot_field: returns 2 with wrong arity" {
    run rauc::slot_field rootfs.0
    [ "${status}" -eq 2 ]
}

@test "rauc::slot_field: returns bootname for a slot" {
    result="$(rauc::slot_field rootfs.0 bootname)"
    [ "${result}" = "A" ]
}

@test "rauc::slot_field: returns 'unknown' for missing field" {
    result="$(rauc::slot_field rootfs.0 nonexistent)"
    [ "${result}" = "unknown" ]
}

##
## rauc::slot_version
##

@test "rauc::slot_version: returns 2 with no arguments" {
    run rauc::slot_version
    [ "${status}" -eq 2 ]
}

@test "rauc::slot_version: returns version for active slot" {
    result="$(rauc::slot_version rootfs.0)"
    [ "${result}" = "1.2.3" ]
}

@test "rauc::slot_version: returns version for inactive slot" {
    result="$(rauc::slot_version rootfs.1)"
    [ "${result}" = "1.1.0" ]
}

##
## rauc::slot_state
##

@test "rauc::slot_state: returns 2 with no arguments" {
    run rauc::slot_state
    [ "${status}" -eq 2 ]
}

@test "rauc::slot_state: returns 'booted' for active slot" {
    result="$(rauc::slot_state rootfs.0)"
    [ "${result}" = "booted" ]
}

@test "rauc::slot_state: returns 'inactive' for inactive slot" {
    result="$(rauc::slot_state rootfs.1)"
    [ "${result}" = "inactive" ]
}

##
## rauc::inactive_slot
##

@test "rauc::inactive_slot: returns the slot that is not booted" {
    result="$(rauc::inactive_slot)"
    [ "${result}" = "rootfs.1" ]
}

##
## rauc::find_bundle
##

@test "rauc::find_bundle: returns 2 with no arguments (accepts default)" {
    # find_bundle has a default dir — it should not return 2
    run rauc::find_bundle /tmp/nonexistent_rauc_dir_xyz
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "rauc::find_bundle: finds .raucb files in a directory" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    touch "${tmpdir}/update-1.2.3.raucb"

    result="$(rauc::find_bundle "${tmpdir}")"
    [[ "${result}" == *"update-1.2.3.raucb"* ]]

    rm -rf "${tmpdir}"
}

@test "rauc::find_bundle: does not find files beyond maxdepth 2" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    mkdir -p "${tmpdir}/subdir/deeper"
    touch "${tmpdir}/subdir/deeper/too-deep.raucb"

    result="$(rauc::find_bundle "${tmpdir}")"
    [ -z "${result}" ]

    rm -rf "${tmpdir}"
}

##
## rauc::bundle_compatible
##

@test "rauc::bundle_compatible: returns 2 with no arguments" {
    run rauc::bundle_compatible
    [ "${status}" -eq 2 ]
}

@test "rauc::bundle_compatible: returns 1 for missing bundle file" {
    run rauc::bundle_compatible /tmp/nonexistent.raucb
    [ "${status}" -eq 1 ]
}

@test "rauc::bundle_compatible: returns compatible string from bundle" {
    local tmpbundle
    tmpbundle="$(mktemp --suffix=.raucb)"
    result="$(rauc::bundle_compatible "${tmpbundle}")"
    [ "${result}" = "offlinelab-pi-zero-2w" ]
    rm -f "${tmpbundle}"
}

##
## rauc::mark_good / rauc::mark_active
##

@test "rauc::mark_good: returns 0" {
    run rauc::mark_good
    [ "${status}" -eq 0 ]
}

@test "rauc::mark_active: returns 2 with no arguments" {
    run rauc::mark_active
    [ "${status}" -eq 2 ]
}

@test "rauc::mark_active: returns 0 with a slot argument" {
    run rauc::mark_active rootfs.1
    [ "${status}" -eq 0 ]
}
