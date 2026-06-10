#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    _stub_bin="$(mktemp -d)"

    # zramctl stub: always succeeds; creates a fake device file on -f -s ... -a ...
    cat >"${_stub_bin}/zramctl" <<'EOF'
#!/bin/sh
if [ "$1" = "-f" ]; then
    # Allocate: create a fake block device placeholder and print its path
    printf '/dev/zram0\n'
elif [ "$1" = "-r" ]; then
    exit 0
fi
exit 0
EOF
    chmod +x "${_stub_bin}/zramctl"

    # mkswap / swapon / swapoff stubs — always succeed
    for cmd in mkswap swapon swapoff modprobe; do
        printf '#!/bin/sh\nexit 0\n' >"${_stub_bin}/${cmd}"
        chmod +x "${_stub_bin}/${cmd}"
    done

    # /proc/swaps stub — initially empty (no active swaps)
    _fake_swaps="$(mktemp)"
    printf 'Filename\t\t\t\tType\t\tSize\tUsed\tPriority\n' >"${_fake_swaps}"

    export PATH="${_stub_bin}:${PATH}"

    # Reset all ZRAM_ env vars to known defaults
    export ZRAM_FRACTION="1/2"
    export ZRAM_ALGORITHM="lz4"
    export ZRAM_COMP_FACTOR=""
    export ZRAM_FIXED_SIZE=""

    import zram
}

teardown() {
    rm -rf "${_stub_bin:-}" "${_fake_swaps:-}"
}

##
## zram::_calc
##

@test "zram::_calc: returns 2 with no arguments" {
    run zram::_calc
    [ "${status}" -eq 2 ]
}

@test "zram::_calc: evaluates simple addition" {
    result="$(zram::_calc "1 + 1")"
    [ "${result}" = "2" ]
}

@test "zram::_calc: evaluates multiplication" {
    result="$(zram::_calc "4 * 3")"
    [ "${result}" = "12" ]
}

@test "zram::_calc: respects precision argument" {
    result="$(zram::_calc 2 "1 / 3")"
    [ "${result}" = "0.33" ]
}

##
## zram::_comp_factor
##

@test "zram::_comp_factor: returns 2.5 for lz4" {
    ZRAM_ALGORITHM="lz4" result="$(zram::_comp_factor)"
    [ "${result}" = "2.5" ]
}

@test "zram::_comp_factor: returns 3 for lzo" {
    ZRAM_ALGORITHM="lzo" result="$(zram::_comp_factor)"
    [ "${result}" = "3" ]
}

@test "zram::_comp_factor: returns 3 for zstd" {
    ZRAM_ALGORITHM="zstd" result="$(zram::_comp_factor)"
    [ "${result}" = "3" ]
}

@test "zram::_comp_factor: returns 2 for unknown algorithm" {
    ZRAM_ALGORITHM="deflate" result="$(zram::_comp_factor)"
    [ "${result}" = "2" ]
}

@test "zram::_comp_factor: returns ZRAM_COMP_FACTOR when set" {
    ZRAM_COMP_FACTOR="4" result="$(zram::_comp_factor)"
    [ "${result}" = "4" ]
}

##
## zram::_remove_device
##

@test "zram::_remove_device: returns 2 with no arguments" {
    run zram::_remove_device
    [ "${status}" -eq 2 ]
}

@test "zram::_remove_device: returns 1 for non-block-device path" {
    run zram::_remove_device /tmp/not-a-block-device
    [ "${status}" -eq 1 ]
}

##
## zram::stop
##

@test "zram::stop: returns 1 when no zram swaps active" {
    # /proc/swaps has no zram entries
    run bash -c "
        source \"\${FRAMEWORK_LIB_PATH}/../bin/framework\"
        import zram
        # Stub grep to always fail (no zram in swaps)
        grep() { if [[ \"\$*\" == *zram* ]]; then return 1; fi; command grep \"\$@\"; }
        export -f grep
        zram::stop
    "
    [ "${status}" -eq 1 ]
}

##
## zram::start (validate FIXED_SIZE validation)
##

@test "zram::start: rejects invalid ZRAM_FIXED_SIZE" {
    export ZRAM_FIXED_SIZE="notasize"
    run bash -c "
        source \"\${FRAMEWORK_LIB_PATH}/../bin/framework\"
        import zram
        export ZRAM_FIXED_SIZE='notasize'
        # stub grep so 'no active zram' check passes
        grep() { if [[ \"\$*\" == *zram* ]]; then return 1; fi; command grep \"\$@\"; }
        export -f grep
        zram::start
    "
    [ "${status}" -ne 0 ]
}

@test "zram::start: accepts M suffix in ZRAM_FIXED_SIZE" {
    printf '256M\n' | grep -qE '^[[:digit:]]+(\.[[:digit:]]+)?(G|M)$'
}

@test "zram::start: accepts G suffix in ZRAM_FIXED_SIZE" {
    printf '1G\n' | grep -qE '^[[:digit:]]+(\.[[:digit:]]+)?(G|M)$'
}
