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
set -e -u -o pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

export builder_name="${builder_name:-offlinelab-builder}"
export builder_base_image="${builder_base_image:-debian}"
export builder_base_tag="${builder_base_tag:-trixie}"
export builder_basedir="${builder_basedir:-}"
export builder_githash="${builder_githash:-}"

if [[ -z "${builder_basedir:-}" ]]; then
    builder_basedir="$(
        git rev-parse --show-toplevel 2>/dev/null || realpath .
    )"
    export builder_basedir="${builder_basedir:-}"
fi

if [[ -z "${builder_githash:-}" ]]; then
    builder_githash="$(
        git rev-parse --short HEAD 2>/dev/null || :
    )"
    export builder_githash="${builder_githash:-}"
fi

################################################################################
# Logger                                                                       #
################################################################################

function log::formatter() {
    local timestamp level logline color

    level="${1}"
    shift

    case "${level}" in
        ERROR) color="\e[1;91m" ;;
        INFO) color="\e[1;32m" ;;
        WARNING) color="\e[1;33m" ;;
        TRACE) color="\e[1;90m" ;;
        DEBUG) color="\e[1;94m" ;;
        *) color="\e[1;90m" ;;
    esac

    timestamp="$(date +"[%T]")"
    logline="${color}[+]\e[0m\e[1m\e[1;97m%s\e[0m - ${color}%-7s\e[0m %-25s - %s\e[0m\n"

    # shellcheck disable=SC2059
    printf "${logline}" "${timestamp}" "${level}" "${FUNCNAME[2]}" "${*}" &>/dev/stderr
}

function log::debug() { log::formatter DEBUG "${@}"; }
function log::info() { log::formatter INFO "${@}"; }
function log::warning() { log::formatter WARNING "${@}"; }
function log::error() { log::formatter ERROR "${@}"; }

################################################################################
# Check if running inside a container                                          #
################################################################################

function build::is_docker() {
    [[ -f /.dockerenv ]] || grep -qsw docker /proc/1/cgroup 2>/dev/null
}

################################################################################
# Check if docker is up                                                        #
################################################################################

function build::docker_up() {
    if ! timeout 5 docker ps --quiet >/dev/null 2>&1; then
        log::error "Error connecting to docker"
        return 1
    fi
    return 0
}

################################################################################
# Get the ID of the running container                                          #
################################################################################

function build::get_container_id() {
    local container_id

    if ! container_id="$(
        timeout 5 docker ps \
            --filter "ancestor=${builder_name}" \
            --format '{{.ID}}'
    )"; then
        log::error "Failed to access docker daemon!"
        return 1
    fi

    if [[ -z "${container_id}" ]]; then
        log::error "Container ${builder_name} not found!"
        return 1
    fi

    echo "${container_id}"
    return 0
}

################################################################################
# Build the docker container                                                   #
################################################################################

function build::build_container() {
    local -a build_arguments=(
        --tag "${builder_name}"
        --file "${builder_basedir}/Dockerfile"
        --build-arg BASE_IMAGE="${builder_base_image}"
        --build-arg BASE_TAG="${builder_base_tag}"
    )

    if [[ -n "${APT_PROXY:-}" ]]; then
        build_arguments+=(--build-arg APT_PROXY="${APT_PROXY}")
    fi

    if ! docker build "${build_arguments[@]}" "${builder_basedir}"; then
        log::error "Failed to build docker container!"
        return 1
    fi

    return 0
}

################################################################################
# Run a container                                                              #
################################################################################

function build::run() {
    local mem_bytes
    mem_bytes="$(sysctl -n hw.memsize 2>/dev/null || echo 8589934592)"
    local mem_gb
    mem_gb="$(awk -v m="${mem_bytes}" 'BEGIN { printf "%.0fg", m / 1073741824 * 0.9 }')"

    local -a run_arguments=(
        --tty
        --interactive
        --privileged
        --workdir /work
        --platform linux/arm64
        --hostname builder.offline-lab.com
        --cpus "$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
        --memory "${mem_gb}"

        --env builder_name="${builder_name}"
        --env builder_basedir="${builder_basedir}"
        --env builder_githash="${builder_githash}"
        --env builder_base_image="${builder_base_image}"
        --env builder_base_tag="${builder_base_tag}"

        --volume "${builder_basedir}/bin/builder.sh:/builder.sh:ro"
        --volume "${builder_basedir}/bin:/work/bin:ro"
        --volume "${builder_basedir}/br2-external:/work/br2-external"

        --volume "${builder_basedir}/artifacts:/artifacts"
        --volume "${HOME}/.cache/buildroot/dl:/downloads"
        --volume "${HOME}/.cache/buildroot/ccache:/buildroot/.ccache"
        --volume "${HOME}/.cache/buildroot/output.img:/buildroot/output.img"
    )

    if [[ -f "${builder_basedir}/.config" ]]; then
        run_arguments+=(--volume "${builder_basedir}/.config:/work/.config")
    fi

    if [[ -f "${builder_basedir}/.env" ]]; then
        run_arguments+=(--volume "${builder_basedir}/.env:/work/.env:ro")
    fi

    log::info "Starting docker container ${builder_name}"

    docker run "${run_arguments[@]}" "${builder_name}" "${@}"
}

################################################################################
# Exec a running container                                                     #
################################################################################

function build::exec() {
    local container_id

    if ! container_id="$(build::get_container_id)"; then
        log::error "Container ${builder_name} not found!"
        exit 1
    fi

    local -a run_arguments=(
        --tty
        --interactive
        --privileged
        --workdir /work
        --env builder_name="${builder_name}"
        --env builder_basedir="${builder_basedir}"
        --env builder_githash="${builder_githash}"
        --env builder_base_image="${builder_base_image}"
        --env builder_base_tag="${builder_base_tag}"
    )

    log::info "Entering docker container ${container_id}"

    docker exec "${run_arguments[@]}" "${container_id}" "${@}"
}

################################################################################
# Cleanup function                                                             #
################################################################################

function build::cleanup() {
    log::error "got CTRL+C... please wait 5s"
    docker stop -t 5 "${builder_name}"
}

################################################################################
# Print help output                                                            #
################################################################################

function build::usage() {
    cat <<EOF

    Offline Lab OS image builder based on buildroot.
    Builds a minimal operating system for running systemd portable services.

    Usage:
      bin/builder.sh --<action> <arguments>

    Script functionality:
      --build                   - Build the OS image
      --build-docker            - Build the container environment
      --shell                   - Run a shell in the container environment
      --exec                    - Exec into a running container

    Options:
      -a | --all                - Build the container and then the image
      -h | --help               - Show this help menu
      -d | --debug              - Verbose debug output

    Example:
      \$ bin/builder.sh --build-docker --shell
      \$ bin/builder.sh --all

EOF
    exit 0
}

################################################################################
# The main function                                                            #
################################################################################

function build::main() {
    if [[ "${#}" -lt 1 ]]; then
        build::usage
    fi

    local -a arguments=()

    local -i action_build=0
    local -i action_shell=0
    local -i action_exec=0
    local -i action_build_docker=0
    local -i action_cleanup=0

    while [[ "${1:-}" != "" ]]; do
        case "${1}" in
            -d | --debug)
                set -x
                shift
                ;;
            -h | --help)
                shift
                build::usage
                ;;
            --build)
                shift
                action_build=1
                ;;
            --shell)
                shift
                action_shell=1
                ;;
            --exec)
                shift
                action_exec=1
                ;;
            --build-docker)
                shift
                action_build_docker=1
                ;;
            --cleanup)
                shift
                action_cleanup=1
                ;;
            -a | --all)
                action_build=1
                action_build_docker=1
                shift
                ;;
            *)
                arguments+=("${1:-}")
                shift
                ;;
        esac
    done

    if [[ "$((action_shell + action_exec + action_build_docker + action_build + action_cleanup))" -eq 0 ]]; then
        build::usage
    fi

    #
    # Source env file if it exists
    #
    if [[ -f "${builder_basedir}/.env" ]]; then
        # shellcheck disable=SC1091
        source "${builder_basedir}/.env"
    fi

    if build::is_docker; then
        if [[ "$((action_shell + action_exec + action_build_docker + action_cleanup))" -gt 0 ]]; then
            build::usage
        fi
        :
    else
        require_tools docker git awk truncate
        if [[ "$((action_shell + action_build))" -gt 0 ]]; then
            [[ -d "${builder_basedir}/artifacts" ]] || mkdir -p "${builder_basedir}/artifacts"
            [[ -d "${HOME}/.cache/buildroot" ]] || mkdir -p "${HOME}/.cache/buildroot/dl" "${HOME}/.cache/buildroot/ccache"

            if [[ ! -f "${HOME}/.cache/buildroot/output.img" ]]; then
                log::info "Creating buildroot output disk image (15GB sparse)"
                truncate -s 15G "${HOME}/.cache/buildroot/output.img"
            fi
        fi

        if ! build::docker_up; then
            log::error "Error connecting to docker"
            return 1
        fi

        if [[ "${action_cleanup}" -eq 1 ]]; then
            build::cleanup || {
                log::error "Failed to cleanup"
                return 1
            }
        fi

        if [[ "${action_build_docker}" -eq 1 ]]; then
            build::build_container || {
                log::error "Failed to build docker container"
                return 1
            }
        fi

        if [[ "${action_build}" -eq 1 ]]; then
            build::run /work/bin/build.sh "${arguments[@]+"${arguments[@]}"}" || {
                log::error "Failed to build image"
                return 1
            }
        fi

        if [[ "$((action_shell + action_exec))" -ge 1 ]]; then
            local -a shell_command=(/bin/bash)
            if [[ "${#arguments[@]}" -gt 0 ]]; then
                shell_command+=(-c "${arguments[@]}")
            fi

            if [[ "${action_shell}" -eq 1 ]]; then
                build::run "${shell_command[@]}" || {
                    log::error "Failed to run shell"
                    return 1
                }
            elif [[ "${action_exec}" -eq 1 ]]; then
                build::exec "${shell_command[@]}" || {
                    log::error "Failed to exec"
                    return 1
                }
            fi
        fi
    fi

    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    build::main "${@}"
fi
