#!/usr/bin/env bash
################################################################################
#         ____  ___________               __          __                       #
#        / __ \/ __/ __/ (_)___  ___     / /   ____ _/ /_                      #
#       / / / / /_/ /_/ / / __ \/ _ \   / /   / __ `/ __ \                     #
#      / /_/ / __/ __/ / / / / /  __/  / /___/ /_/ / /_/ /                     #
#      \____/_/ /_/ /_/_/_/ /_/\___/  /_____/\__,_/_.___/                      #
#                                                                              #
#      Copyright (C) 2025-2026 Offline Lab                                     #
#      Contact: info@offline-lab.com                                           #
#      SPDX-License-Identifier: AGPL-3.0-only                                  #
################################################################################

# vi: ft=bash
# shellcheck shell=bash
#
# Shared functions for build scripts.
# Source this file, do not execute it directly.
#

if [[ -z "${_COMMON_SH_LOADED:-}" ]]; then
    readonly _COMMON_SH_LOADED=1
else
    return 0
fi

function log() {
    printf '\e[1;32m>>>\e[0m %s\n' "${*}"
}

function log_err() {
    printf '\e[1;31m!!!\e[0m %s\n' "${*}" >&2
}

function log_dim() {
    printf '\e[0;90m    %s\e[0m\n' "${*}"
}

function require_tools() {
    local missing=0

    for tool in "${@}"; do
        if ! command -v "${tool}" &>/dev/null; then
            log_err "Required tool not found: ${tool}"
            missing=$((missing + 1))
        fi
    done

    if [[ "${missing}" -gt 0 ]]; then
        log_err "Install the ${missing} missing tool(s) above, then re-run."
        return 1
    fi
}
