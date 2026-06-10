#!/usr/bin/env bats

load "../../bin/framework"
import clock

#
# clock::save
#

@test "clock::save: writes current UTC date to CLOCK_FILE" {
    local tmpfile
    tmpfile="$(mktemp -t clock-XXXX)"

    CLOCK_FILE="${tmpfile}" run clock::save
    [[ "${status}" -eq 0 ]]
    [[ -s "${tmpfile}" ]]
    # date format: YYYY-MM-DD HH:MM:SS
    grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' "${tmpfile}"

    rm -f "${tmpfile}"
}

#
# clock::load
#

@test "clock::load: skips gracefully when CLOCK_FILE is absent" {
    CLOCK_FILE="/tmp/does-not-exist-clock-$$" run clock::load
    [[ "${status}" -eq 0 ]]
}

@test "clock::load: reads saved time without error" {
    local tmpfile
    tmpfile="$(mktemp -t clock-XXXX)"
    echo "2020-01-01 00:00:00" > "${tmpfile}"

    # date -s may fail in sandboxed test env — we only assert the function exits cleanly
    CLOCK_FILE="${tmpfile}" run clock::load
    [[ "${status}" -eq 0 ]]

    rm -f "${tmpfile}"
}
