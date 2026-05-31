#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

################################################################################
# Credentials                                                                  #
################################################################################

function credentials::generate_random_username() {
    local prefix suffix suffix_length total_suffix_length timestamp username

    log::trace "${FUNCNAME[0]}: Generating random username"

    prefix="${1:-}"
    suffix="${2:-}"

    suffix_length="${#suffix}"
    total_suffix_length="$((10 + suffix_length))"
    timestamp="$(date '+%Y%m%d')"

    username="$(tr -dc 'A-Za-z0-9' <<<"${prefix}")"
    suffix="$(tr -dc 'A-Za-z0-9' <<<"${suffix}")"

    echo "${username:0:$((63 - total_suffix_length))}_${suffix}_${timestamp}"
}

function credentials::generate_random_password() {
    local length password

    log::trace "${FUNCNAME[0]}: Generating random password"

    length="${1:-30}"
    password="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${length}")" || true

    echo "${password}"
}

################################################################################
# EOF                                                                          #
################################################################################
