#!/usr/bin/env bash
# This is a special library.
# To prevent chicken and egg problems, we source directly
# instead of using our import function.
# shellcheck source=/dev/null shell=bash disable=SC2312

declare FRAMEWORK_LIB_PATH="${FRAMEWORK_LIB_PATH:-}"

source "${FRAMEWORK_LIB_PATH}/import.sh" || exit 1
source "${FRAMEWORK_LIB_PATH}/logging.sh" || exit 1
source "${FRAMEWORK_LIB_PATH}/exit.sh" || exit 1
