#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash

set -euo pipefail

docker_image="offline-lab-debos-builder"

#
# Check if running inside a container
#
function build::is_container() {
    [[ -f /.dockerenv ]] || grep -qsw docker /proc/1/cgroup 2>/dev/null
}

#
# Build the docker image and re-execute this script inside it
#
function build::run_in_docker() {
    local repo_root githash

    local -a build_arguments=(
        --tag "${docker_image}"
    )

    if [[ -n "${APT_PROXY}" ]]; then
        build_arguments+=(
            --build-arg APT_PROXY="${APT_PROXY}"
        )
    fi

    echo "==> Building Docker image..."

    repo_root="$(git rev-parse --show-toplevel)"

    if ! docker build "${build_arguments[@]}" "${repo_root}"; then
        echo "ERROR: Failed to build docker container!"
        exit 1
    fi

    githash="$(git rev-parse --short HEAD)"

    local -a run_arguments=(
        --rm
        --tty
        --interactive
        --privileged
        --platform linux/arm64
        -e githash="$(git rev-parse --short HEAD)"
        -w /work
        -v "${repo_root}/overlays:/work/overlays:ro"
        -v "${repo_root}/recipes:/work/recipes:ro"
        -v "${repo_root}/offline-lab.yaml:/work/offline-lab.yaml:ro"
        -v "${repo_root}/bin/build.sh:/build.sh:ro"
        -v "${repo_root}/output:/output"
    )

    if [[ -n "${APT_PROXY}" ]]; then
        run_arguments+=(
            -e APT_PROXY="${APT_PROXY}"
            -e http_proxy="${APT_PROXY}"
            -e https_proxy="${APT_PROXY}"
        )
    fi

    exec docker run "${run_arguments[@]}" "${docker_image}" /build.sh "${@}"
}

#
# Run the actual build inside the container
#
function build::run() {
    local -a command=("${@}")

    if [[ "${#command[@]}" -lt 1 ]]; then
        local -a arguments=(
            --verbose
            --debug-shell
            --shell=/bin/bash
            --cpus=8
            --memory=8192MB
            --artifactdir=/artifacts
            --template-var version:"$(date +%Y%m%d.%H%M%S.1)"
            --template-var githash:"${githash}"
        )
        exec debos "${arguments[@]}" /work/offline-lab.yaml

    else
        exec "${command[@]}"
    fi

}

#
# Exec a running container
#
function build::exec() {
    local container

    container="$(
        docker ps \
            --filter ancestor=offline-lab-debos-builder \
            --format '{{.ID}}'
    )"

    if [[ -n "${container}" ]]; then
        exec docker exec -ti "${container}" /bin/bash
    fi
}

#
# Main
#
function build::main() {
    if [[ "${*}" =~ --debug ]]; then
        set -x
    fi

    if build::is_container; then
        if [[ "${*}" =~ --shell ]]; then
            /bin/bash
        else
            build::run "${@}"
        fi
    else
        if [[ "${*}" =~ --exec ]]; then
            build::exec
        else
            build::run_in_docker "${@}"
        fi
    fi
}

build::main "$@"
