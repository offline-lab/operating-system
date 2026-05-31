#!/usr/bin/env bash
set -e -u -o pipefail

declare FRAMEWORK_BASE_PATH="${FRAMEWORK_BASE_PATH:-}"

export TESTSUITE_DOCKER_IMAGE_NAME="toolset-bats"
export TESTSUITE_DOCKER_TEMPLATE="${FRAMEWORK_BASE_PATH}/config/templates/dockerfile-bats.tpl"
export TESTSUITE_EXTRA_BUILD_ARGS=()
export TESTSUITE_EXTRA_RUN_ARGS=()
export TESTSUITE_COMMAND=""

#
# Test functions
#

function testsuite::function::test_testsuite_1() {
    return 0
}
function testsuite::function::test_testsuite_2() {
    return 0
}
function testsuite::function::test_testsuite_3() {
    return 0
}
function testsuite::function::test_testsuite_4() {
    return 0
}
function testsuite::function::test_testsuite_5() {
    return 0
}
function testsuite::function::test_testsuite_6() {
    return 0
}
function testsuite::function::test_testsuite_7() {
    return 0
}
function testsuite::function::test_testsuite_8() {
    return 0
}
function testsuite::function::test_testsuite_9() {
    return 0
}
function testsuite::function::test_testsuite_10() {
    return 0
}
function testsuite::function::test_testsuite_11() {
    return 0
}
function testsuite::function::test_testsuite_12() {
    return 0
}
function testsuite::function::test_testsuite_13() {
    return 1
}

function testsuite::function::test_testsuite_14() {
    return 0
}

function testsuite::function::test_testsuite_15() {
    return 1
}
