#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    import credentials
}

##
## credentials::generate_random_username
##

@test "credentials::generate_random_username: output contains a datestamp suffix" {
    run credentials::generate_random_username "testuser"
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ [0-9]{8}$ ]]
}

@test "credentials::generate_random_username: strips non-alphanumeric chars from prefix" {
    run credentials::generate_random_username "user-name!"
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ ^username ]]
}

@test "credentials::generate_random_username: output is at most 63 characters" {
    run credentials::generate_random_username "averylongusernameprefixthatshouldgettruncatedproperly"
    [ "${status}" -eq 0 ]
    [ "${#output}" -le 63 ]
}

@test "credentials::generate_random_username: includes suffix when provided" {
    run credentials::generate_random_username "user" "dev"
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ _dev_ ]]
}

@test "credentials::generate_random_username: works with empty prefix" {
    run credentials::generate_random_username ""
    [ "${status}" -eq 0 ]
    [ -n "${output}" ]
}

##
## credentials::generate_random_password
##

@test "credentials::generate_random_password: returns 0" {
    run credentials::generate_random_password
    [ "${status}" -eq 0 ]
}

@test "credentials::generate_random_password: output is non-empty" {
    run credentials::generate_random_password
    [ "${status}" -eq 0 ]
    [ -n "${output}" ]
}

@test "credentials::generate_random_password: default length is 30 characters" {
    run credentials::generate_random_password
    [ "${status}" -eq 0 ]
    [ "${#output}" -eq 30 ]
}

@test "credentials::generate_random_password: respects specified length" {
    run credentials::generate_random_password 16
    [ "${status}" -eq 0 ]
    [ "${#output}" -eq 16 ]
}

@test "credentials::generate_random_password: output is alphanumeric only" {
    run credentials::generate_random_password 64
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ ^[A-Za-z0-9]+$ ]]
}

@test "credentials::generate_random_password: two calls produce different output" {
    local first second
    first="$(credentials::generate_random_password 32)"
    second="$(credentials::generate_random_password 32)"
    [ "${first}" != "${second}" ]
}
