#!/usr/bin/env bats

load "../../bin/framework"

##
## proc::chronic
##

@test "proc::chronic: succeeds and suppresses output on exit 0" {
    run proc::chronic bash -c "echo suppressed; exit 0"
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "proc::chronic: fails and shows output on non-zero exit" {
    run proc::chronic bash -c "echo visible error; exit 1"
    [ "${status}" -eq 1 ]
    [ "${output}" = "visible error" ]
}

@test "proc::chronic: preserves the original exit code" {
    run proc::chronic bash -c "exit 42"
    [ "${status}" -eq 42 ]
}

@test "proc::chronic: suppresses stderr on exit 0" {
    run proc::chronic bash -c "echo error >&2; exit 0"
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "proc::chronic: shows combined stdout+stderr on failure" {
    run proc::chronic bash -c "echo out; echo err >&2; exit 1"
    [ "${status}" -eq 1 ]
    [[ "${output}" =~ "out" ]]
    [[ "${output}" =~ "err" ]]
}

@test "proc::chronic: returns 2 with no arguments" {
    run proc::chronic
    [ "${status}" -eq 2 ]
}

##
## proc::run
##

@test "proc::run: echoes true and returns 0 on success" {
    run proc::run "true"
    [ "${status}" -eq 0 ]
    [ "${output}" = "true" ]
}

@test "proc::run: echoes false and returns 1 on failure" {
    run proc::run "false"
    [ "${status}" -eq 1 ]
    [ "${output}" = "false" ]
}

##
## proc::all / proc::any / proc::none
##

@test "proc::all: returns 0 when all commands succeed" {
    run proc::all "true" "true"
    [ "${status}" -eq 0 ]
}

@test "proc::all: returns 1 when any command fails" {
    run proc::all "true" "false"
    [ "${status}" -eq 1 ]
}

@test "proc::any: returns 0 when at least one command succeeds" {
    run proc::any "false" "true"
    [ "${status}" -eq 0 ]
}

@test "proc::any: returns 1 when all commands fail" {
    run proc::any "false" "false"
    [ "${status}" -eq 1 ]
}

@test "proc::none: returns 0 when all commands fail" {
    run proc::none "false" "false"
    [ "${status}" -eq 0 ]
}

@test "proc::none: returns 1 when any command succeeds" {
    run proc::none "false" "true"
    [ "${status}" -eq 1 ]
}

##
## arity checks
##

@test "proc::chronic: returns 2 with no arguments (already tested above)" {
    run proc::chronic
    [ "${status}" -eq 2 ]
}

@test "proc::assert_command: returns 2 with fewer than 2 arguments" {
    run proc::assert_command
    [ "${status}" -eq 2 ]
    run proc::assert_command onlyone
    [ "${status}" -eq 2 ]
}

@test "proc::log_output: returns 2 with fewer than 2 arguments" {
    run proc::log_output
    [ "${status}" -eq 2 ]
    run proc::log_output onlyone
    [ "${status}" -eq 2 ]
}

@test "proc::log_action: returns 2 with no arguments" {
    run proc::log_action
    [ "${status}" -eq 2 ]
}

@test "proc::watch: returns 2 with no arguments" {
    run proc::watch
    [ "${status}" -eq 2 ]
}

@test "proc::run: returns 2 with no arguments" {
    run proc::run
    [ "${status}" -eq 2 ]
}

@test "proc::runall: returns 2 with no arguments" {
    run proc::runall
    [ "${status}" -eq 2 ]
}

@test "proc::all: returns 2 with no arguments" {
    run proc::all
    [ "${status}" -eq 2 ]
}

@test "proc::any: returns 2 with no arguments" {
    run proc::any
    [ "${status}" -eq 2 ]
}

@test "proc::none: returns 2 with no arguments" {
    run proc::none
    [ "${status}" -eq 2 ]
}
