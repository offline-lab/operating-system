#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    import ssh
}

##
## ssh::generate_ssh_keypair
##

@test "ssh::generate_ssh_keypair: returns 2 with no arguments" {
    run ssh::generate_ssh_keypair
    [ "${status}" -eq 2 ]
}

##
## ssh::connect
##

@test "ssh::connect: returns 2 with no arguments" {
    run ssh::connect
    [ "${status}" -eq 2 ]
}

@test "ssh::connect: returns 2 with fewer than 3 arguments" {
    run ssh::connect user host
    [ "${status}" -eq 2 ]
}

##
## ssh::run
##

@test "ssh::run: returns 2 with no arguments" {
    run ssh::run
    [ "${status}" -eq 2 ]
}

@test "ssh::run: returns 2 with fewer than 4 arguments" {
    run ssh::run user host key
    [ "${status}" -eq 2 ]
}

##
## ssh::test_connection
##

@test "ssh::test_connection: returns 2 with no arguments" {
    run ssh::test_connection
    [ "${status}" -eq 2 ]
}

@test "ssh::test_connection: returns 2 with fewer than 3 arguments" {
    run ssh::test_connection user host
    [ "${status}" -eq 2 ]
}

##
## ssh::create_tunnel
##

@test "ssh::create_tunnel: returns 2 with no arguments" {
    run ssh::create_tunnel
    [ "${status}" -eq 2 ]
}

@test "ssh::create_tunnel: returns 2 with fewer than 6 arguments" {
    run ssh::create_tunnel user host key endpoint port
    [ "${status}" -eq 2 ]
}

##
## ssh::port_available
##

@test "ssh::port_available: returns 2 with no arguments" {
    run ssh::port_available
    [ "${status}" -eq 2 ]
}
