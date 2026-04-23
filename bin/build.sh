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
    local repo_root

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

    local -a run_arguments=(
        --rm
        --tty
        --interactive
        --privileged
        --platform linux/arm64
        -w /work
        -v "${repo_root}/recipes:/work/recipes:ro"
        -v "${repo_root}/overlays:/work/overlays:ro"
        -v "${repo_root}/offline-lab.yaml:/work/offline-lab.yaml:ro"
        -v "${repo_root}/bin/build.sh:/build.sh:ro"
        -v "${repo_root}/build/artifacts:/artifacts"
    )

    if [[ -n "${APT_PROXY}" ]]; then
        run_arguments+=(
            -e APT_PROXY="${APT_PROXY}"
            -e http_proxy="${APT_PROXY}"
            -e https_proxy="${APT_PROXY}"
        )
    fi

    echo "==> Starting build in Docker..."

    exec docker run "${run_arguments[@]}" "${docker_image}" /build.sh "${@}"
}

#
# Run the actual build inside the container
#
function build::run() {
    local -a arguments=(
        --verbose
        --debug-shell
        --shell=/bin/bash
        --cpus=8
        --memory=8192MB
        --artifactdir=/artifacts
    )

    echo "==> Building image..."

    exec debos "${arguments[@]}" /work/offline-lab.yaml
}

#
# Main
#
function build::main() {
    if build::is_container; then
        build::run
    else
        build::run_in_docker "${@}"
    fi
}

build::main "$@"
