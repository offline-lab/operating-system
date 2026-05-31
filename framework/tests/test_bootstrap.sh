#!/usr/bin/env bash
declare FRAMEWORK_BASE_PATH="${FRAMEWORK_BASE_PATH:-}"

export TESTSUITE_DOCKER_IMAGE_NAME="toolset-bootstrap"
export TESTSUITE_DOCKER_TEMPLATE="${FRAMEWORK_BASE_PATH}/config/templates/dockerfile-bootstrap.tpl"
export TESTSUITE_EXTRA_BUILD_ARGS=()
export TESTSUITE_EXTRA_RUN_ARGS=()
export TESTSUITE_COMMAND="/home/devbox/.toolset/bootstrap --install"
