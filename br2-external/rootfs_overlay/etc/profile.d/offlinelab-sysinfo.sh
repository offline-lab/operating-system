#!/usr/bin/env bash
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
