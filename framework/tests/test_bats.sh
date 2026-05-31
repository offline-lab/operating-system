#!/usr/bin/env bash
set -e -u -o pipefail

declare FRAMEWORK_BASE_PATH="${FRAMEWORK_BASE_PATH:-"$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"}"

function testsuite::function::test_bats() {
    local bats_tests="${FRAMEWORK_BASE_PATH}/tests/unit"

    pushd "${FRAMEWORK_BASE_PATH}" >/dev/null || return 1

    bats --pretty -r "${bats_tests}"

    popd >/dev/null || return 1
}

testsuite::function::test_bats
