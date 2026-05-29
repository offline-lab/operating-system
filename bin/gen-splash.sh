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

SVG_IN="${1:?Usage: gen-splash.sh <input.svg> <output.png> [version]}"
PNG_OUT="${2:?Usage: gen-splash.sh <input.svg> <output.png> [version]}"
VERSION="${3:-$(date +%Y%m%d)}"

if ! command -v rsvg-convert &>/dev/null; then
    echo "ERROR: rsvg-convert not found (install librsvg2-bin)" >&2
    exit 1
fi

tmpsvg="$(mktemp)"
trap 'rm -f "${tmpsvg}"' EXIT

sed "s/@@VERSION@@/${VERSION}/g" "${SVG_IN}" > "${tmpsvg}"
rsvg-convert -w 1920 -h 1080 "${tmpsvg}" -o "${PNG_OUT}"
