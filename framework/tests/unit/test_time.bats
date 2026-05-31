#!/usr/bin/env bats

load "../../bin/framework"

##
## time::human_readable_seconds
##

@test "time::human_readable_seconds: returns 2 with no arguments" {
    run time::human_readable_seconds
    [ "${status}" -eq 2 ]
}

@test "time::human_readable_seconds: formats 0 seconds" {
    run time::human_readable_seconds 0
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "0 seconds" ]]
}

@test "time::human_readable_seconds: formats 45 seconds" {
    run time::human_readable_seconds 45
    [ "${status}" -eq 0 ]
    [ "${output}" = "45 seconds" ]
}

@test "time::human_readable_seconds: formats 90 seconds as minutes and seconds" {
    run time::human_readable_seconds 90
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "1 minute(s)" ]]
    [[ "${output}" =~ "30 seconds" ]]
}

@test "time::human_readable_seconds: formats 12333 seconds (original test)" {
    run time::human_readable_seconds 12333
    [ "${status}" -eq 0 ]
    [ "${output}" = "3 hours 25 minute(s) and 33 seconds" ]
}

@test "time::human_readable_seconds: formats 3661 seconds as hours, minutes, seconds" {
    run time::human_readable_seconds 3661
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "1 hours" ]]
    [[ "${output}" =~ "1 minute(s)" ]]
    [[ "${output}" =~ "1 seconds" ]]
}

@test "time::human_readable_seconds: formats 86400 seconds as 1 day" {
    run time::human_readable_seconds 86400
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "1 days" ]]
}

##
## time::now
##

@test "time::now: returns a non-empty string" {
    run time::now
    [ "${status}" -eq 0 ]
    [ -n "${output}" ]
}

@test "time::now: output is a positive integer" {
    run time::now
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ ^[0-9]+$ ]]
}

@test "time::now: returns a plausible unix timestamp (after 2024-01-01)" {
    run time::now
    [ "${status}" -eq 0 ]
    [ "${output}" -gt 1704067200 ]
}

@test "time::now: accepts a timezone argument" {
    run time::now "UTC"
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ ^[0-9]+$ ]]
}
