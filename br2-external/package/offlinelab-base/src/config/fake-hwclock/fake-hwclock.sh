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

set -e -u -o pipefail

CLOCK_FILE="/data/config/fake-hwclock.data"

case "${1:-}" in
    load)
        [[ -f "${CLOCK_FILE}" ]] || exit 0
        date -u -s "$(cat "${CLOCK_FILE}")" >/dev/null 2>&1 || true
        echo "fake-hwclock: restored to $(cat "${CLOCK_FILE}")"
        ;;
    save)
        mkdir -p "$(dirname "${CLOCK_FILE}")"
        date -u '+%Y-%m-%d %H:%M:%S' > "${CLOCK_FILE}"
        ;;
    *)
        echo "Usage: ${0} (load|save)" >&2
        exit 1
        ;;
esac
