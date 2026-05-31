#!/usr/bin/env bats

load "../../bin/framework"


##
## arguments::in_args
##

@test "Test that arguments::in_args returns 0 if expected arg is given" {
    local -a input=(--some --arguments -h)

    run arguments::in_args "--some" "${input[@]}"

    [ "$status" -eq 0 ]

    local -a input=(--some --arguments -h)

    run arguments::in_args "--arguments" "${input[@]}"

    [ "$status" -eq 0 ]
}

@test "Test that arguments::in_args returns 1 if expected arg is not given" {
    local -a input=(--some --arguments)

    run arguments::in_args "--whatever" "${input[@]}"

    [ "$status" -eq 1 ]
}

##
## arity checks
##

@test "arguments::get_variable_name: returns 2 with no arguments" {
    run arguments::get_variable_name
    [ "${status}" -eq 2 ]
}

@test "arguments::get_variable_name: returns 2 with more than 2 arguments" {
    run arguments::get_variable_name a b c
    [ "${status}" -eq 2 ]
}

@test "arguments::in_args: returns 2 with fewer than 2 arguments" {
    run arguments::in_args
    [ "${status}" -eq 2 ]
    run arguments::in_args onlyone
    [ "${status}" -eq 2 ]
}
