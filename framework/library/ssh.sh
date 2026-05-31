#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

################################################################################
# SSH                                                                          #
################################################################################

#
# Generate a private key using dropbearkey.
# Passphrase-protected keys are not supported by dropbear key generation.
# Writes <keyfile>.pub alongside the private key.
#
function ssh::generate_ssh_keypair() {
    log::trace "${FUNCNAME[0]}: Generating SSH keypair"

    [[ "${#}" -lt 1 ]] && return 2
    depends::check::silent dropbearkey || return 1

    local keyfile keytype dirname basename

    keyfile="${1}"
    shift

    basename="$(basename "${keyfile}")"
    keytype="${1:-ed25519}"

    if [[ "${keyfile}" == "${basename}" ]]; then
        dirname="${HOME}/.ssh"
    else
        dirname="${HOME}/.ssh/$(dirname "${keyfile}")"
    fi

    if ! {
        mkdir -p "${dirname}" && chmod 700 "${dirname}"
    }; then
        log::error "${FUNCNAME[0]}: Error creating ${dirname}"
        return 1
    fi

    proc::chronic dropbearkey \
        -t "${keytype}" \
        -f "${dirname}/${keyfile}" || return 1

    dropbearkey -y -f "${dirname}/${keyfile}" |
        grep -E "^(ssh-|ecdsa-)" \
            >"${dirname}/${keyfile}.pub"
}

#
# Open an interactive SSH session
#
function ssh::connect() {
    log::trace "${FUNCNAME[0]}: Connecting over ssh to server"

    [[ "${#}" -ne 3 ]] && return 2
    depends::check::silent dbclient || return 1

    local public_ip key_file username

    username="${1}"
    shift

    public_ip="${1}"
    shift

    key_file="${1}"
    shift

    log::info "${FUNCNAME[0]}: Setting up SSH connection to ${username}@${public_ip}"

    dbclient \
        -t \
        -l "${username}" \
        -i "${key_file}" \
        -y \
        "${public_ip}"
}

#
# Run a command over SSH
#
function ssh::run() {
    log::trace "${FUNCNAME[0]}: Running command over SSH"

    [[ "${#}" -lt 4 ]] && return 2
    depends::check::silent dbclient || return 1

    local public_ip key_file username
    local -a run_command

    username="${1}"
    shift

    public_ip="${1}"
    shift

    key_file="${1}"
    shift

    run_command=("${@}")

    if ! {
        proc::chronic dbclient \
            -l "${username}" \
            -i "${key_file}" \
            -y \
            "${public_ip}" bash -c "${run_command[@]}"
    }; then
        log::error "${FUNCNAME[0]}: Run '${run_command[*]}' over SSH on ${username}@${public_ip} failed!"
        return 1
    fi

    return 0
}

#
# Test SSH connection to a machine
#
function ssh::test_connection() {
    log::trace "${FUNCNAME[0]}: Testing SSH connection"

    [[ "${#}" -ne 3 ]] && return 2

    local public_ip key_file username

    username="${1}"
    shift

    public_ip="${1}"
    shift

    key_file="${1}"
    shift

    if ! {
        ssh::run "${username}" "${public_ip}" "${key_file}" "exit 0"
    }; then
        log::error "${FUNCNAME[0]}: Test to verify SSH connection to ${username}@${public_ip} failed!"
        return 1
    fi
}

#
# Create SSH tunnel
#
function ssh::create_tunnel() {
    log::trace "${FUNCNAME[0]}: Creating SSH tunnel"

    [[ "${#}" -ne 6 ]] && return 2
    depends::check::silent dbclient || return 1

    local username public_ip key_file endpoint port local_port

    username="${1}"
    shift

    public_ip="${1}"
    shift

    key_file="${1}"
    shift

    endpoint="${1}"
    shift

    port="${1}"
    shift

    local_port="${1}"
    shift

    log::info "${FUNCNAME[0]}: Setting up tunnel from localhost:${local_port} through ${public_ip} to ${endpoint}:${port}"

    if ! {
        proc::chronic dbclient \
            -N \
            -l "${username}" \
            -i "${key_file}" \
            -y \
            -L "${local_port}:${endpoint}:${port}" \
            "${public_ip}"
    }; then
        log::error "${FUNCNAME[0]}: Failed to setup tunnel from ${local_port} through ${username}@${public_ip} to ${endpoint}:${port}"
        return 1
    fi
}

#
# Check if a port is available for a tunnel
#
function ssh::port_available() {
    log::trace "${FUNCNAME[0]}: Checking if port is available"

    [[ "${#}" -ne 1 ]] && return 2

    local port="${1}"
    shift

    if fs::is_port "${port}"; then
        return 1
    fi

    return 0
}

################################################################################
# EOF                                                                          #
################################################################################
