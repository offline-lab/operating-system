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
# shellcheck shell=bash disable=SC2312

# shellcheck source=/dev/null
source /etc/os-release 2>/dev/null || true

printf '  %-9s%s\n'  "Version:" "${VERSION_ID:-unknown}"
printf '  %-9s%s\n'  "Build:"   "${BUILD_ID:-unknown}"
printf '  %-9s%s\n'  "Kernel:"  "$(uname -r)"
printf '  %-9s%s\n'  "Host:"    "$(hostname)"
printf '\n'
printf '  Docs:    https://docs.offline-lab.com\n'
printf '  GitHub:  https://github.com/offline-lab\n'
printf '  Issues:  https://github.com/offline-lab/builder/issues\n'
printf '\n'
