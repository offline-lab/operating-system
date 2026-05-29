#!/bin/bash
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
START_YEAR=2025
YEAR="${1:-$(date +%Y)}"
MARKER="SPDX-License-Identifier: AGPL-3.0-only"

make_banner() {
    local yr="${1:-$YEAR}"
    echo '################################################################################'
    echo '#         ____  ___________               __          __                       #'
    echo '#        / __ \/ __/ __/ (_)___  ___     / /   ____ _/ /_                      #'
    echo '#       / / / / /_/ /_/ / / __ \/ _ \   / /   / __ `/ __ \                     #'
    echo '#      / /_/ / __/ __/ / / / / /  __/  / /___/ /_/ / /_/ /                     #'
    echo '#      \____/_/ /_/ /_/_/_/ /_/\___/  /_____/\__,_/_.___/                      #'
    echo '#                                                                              #'
    printf '#      %-72s#\n' "Copyright (C) ${START_YEAR}-${yr} Offline Lab"
    printf '#      %-72s#\n' "Contact: info@offline-lab.com"
    printf '#      %-72s#\n' "SPDX-License-Identifier: AGPL-3.0-only"
    echo '################################################################################'
}

has_banner() { grep -q "$MARKER" "$1" 2>/dev/null; }

find_target_files() {
    cd "$REPO_ROOT"
    git ls-files --cached --others --exclude-standard | while IFS= read -r f; do
        [[ -f "$f" ]] && [[ ! -L "$f" ]] || continue
        case "$f" in
            .claude/*|.github/*|.editorconfig)              continue ;;
            */configs/linux.config)                         continue ;;
            */.empty|*/splash.svg)                          continue ;;
            */cloud-init/*)                                 continue ;;
            */external.desc|*/genimage.cfg.in)              continue ;;
            */etc/passwd|*/etc/group|*/etc/shadow)          continue ;;
            */etc/protocols|*/etc/services|*/etc/resolv.conf) continue ;;
            */etc/hosts|*/etc/hostname|*/etc/os-release)    continue ;;
            */users.txt|*/devices.txt|*/cmdline.txt)        continue ;;
            *.md|*.yml|*.yaml|*.svg|*.patch|*.json)         continue ;;
            */config.txt)                  echo "$f" ;;
            *.sh|*.mk)                     echo "$f" ;;
            */Config.in|*/config.yaml)     [[ "$f" == */Config.in ]] && echo "$f" || continue ;;
            Dockerfile)                    echo "$f" ;;
            *.service|*.mount|*.network)   echo "$f" ;;
            *.conf|*.config)               echo "$f" ;;
            */fstab|*/sudoers.d/*)         echo "$f" ;;
            */bash.bashrc|*/.bashrc)       echo "$f" ;;
            */etc/profile)                 echo "$f" ;;
            */boot.cmd|*/init)             echo "$f" ;;
            .gitignore|.dockerignore|.packages.list) echo "$f" ;;
            config.example|env.example)    echo "$f" ;;
            *_defconfig)                   echo "$f" ;;
        esac
    done | sort
}

add_banner() {
    local file="$1"
    local banner
    banner=$(make_banner)
    local first_line
    first_line=$(head -1 "$file")

    if [[ "$first_line" == "#!"* ]]; then
        local rest
        rest=$(tail -n +2 "$file" | sed '/./,$!d')
        { echo "$first_line"; echo "$banner"; echo ""; echo "$rest"; } > "$file.tmp"
    else
        { echo "$banner"; echo ""; cat "$file"; } > "$file.tmp"
    fi
    chmod --reference="$file" "$file.tmp" 2>/dev/null || chmod "$(stat -f '%Lp' "$file")" "$file.tmp"
    mv "$file.tmp" "$file"
}

update_year() {
    local file="$1"
    sed "s/Copyright (C) ${START_YEAR}-[0-9]\{4\} Offline Lab/Copyright (C) ${START_YEAR}-${YEAR} Offline Lab/" "$file" > "$file.tmp"
    chmod --reference="$file" "$file.tmp" 2>/dev/null || chmod "$(stat -f '%Lp' "$file")" "$file.tmp"
    mv "$file.tmp" "$file"
}

added=0
updated=0
skipped=0

while IFS= read -r file; do
    path="$REPO_ROOT/$file"
    if has_banner "$path"; then
        update_year "$path"
        echo "  updated  $file"
        updated=$((updated + 1))
    else
        add_banner "$path"
        echo "  added    $file"
        added=$((added + 1))
    fi
done < <(find_target_files)

echo ""
echo "Done: $added added, $updated updated, $skipped skipped"
