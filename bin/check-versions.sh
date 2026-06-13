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
# shellcheck shell=bash
#
# Check the latest upstream versions of Offline Lab source repos.
# Compares against what is currently pinned in br2-external/.
#
# Usage:
#   bin/check-versions.sh [--update]
#
#   --update   Write the latest version into each Config.in in place.
#              Remember to run <pkg>-dirclean before rebuilding.
#
set -e -u -o pipefail

BASEDIR="$(cd "$(dirname "${0}")/.." && pwd)"
readonly ORG="offline-lab"

# GITHUB_TOKEN from the environment may point to a CI token that lacks access
# to private repos; unset it so gh falls back to the keyring credential.
unset GITHUB_TOKEN

UPDATE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
    --update) UPDATE=true ;;
    *)
        echo "Usage: $(basename "$0") [--update]" >&2
        exit 1
        ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Repos that are pinned to a tag (latest GitHub release, falls back to latest tag)
# Format: "repo:config_file:config_key"
# ---------------------------------------------------------------------------
TAG_REPOS=(
    "bootconf:br2-external/package/offlinelab-bootconf/Config.in:BR2_PACKAGE_OFFLINELAB_BOOTCONF_VERSION"
    "disco:br2-external/package/offlinelab-disco/Config.in:BR2_PACKAGE_OFFLINELAB_DISCO_VERSION"
    # "appctl:br2-external/package/offlinelab-appctl/Config.in:BR2_PACKAGE_OFFLINELAB_APPCTL_VERSION"
    # "buildctl:br2-external/package/offlinelab-buildctl/Config.in:BR2_PACKAGE_OFFLINELAB_BUILDCTL_VERSION"
)

# ---------------------------------------------------------------------------
# Repos that are pinned to a branch commit hash
# Format: "repo:branch:config_file:config_key"
# ---------------------------------------------------------------------------
COMMIT_REPOS=(
    "framework:main:br2-external/package/offlinelab-framework/Config.in:BR2_PACKAGE_OFFLINELAB_FRAMEWORK_VERSION"
)

# ---------------------------------------------------------------------------

pinned_version() {
    local config_file="$1" config_key="$2"
    local path="${BASEDIR}/${config_file}"
    [[ -f "$path" ]] || {
        echo "(no config)"
        return
    }
    awk '/config '"${config_key}"'$/{found=1} found && /default "/{match($0,/"([^"]+)"/,a); print a[1]; exit}' "$path"
}

latest_tag() {
    local repo="$1"
    gh release list --repo "${ORG}/${repo}" --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null ||
        gh api "repos/${ORG}/${repo}/tags" --jq '.[0].name' 2>/dev/null ||
        echo "(unavailable)"
}

latest_commit() {
    local repo="$1" branch="$2"
    gh api "repos/${ORG}/${repo}/commits/${branch}" --jq '.sha' 2>/dev/null ||
        echo "(unavailable)"
}

update_version() {
    local config_file="$1" pinned="$2" latest="$3"
    local path="${BASEDIR}/${config_file}"
    sed -i "s/default \"${pinned}\"/default \"${latest}\"/" "$path"
}

# Derive the .hash file path from the Config.in path.
# e.g. br2-external/package/offlinelab-bootconf/Config.in
#   -> br2-external/package/offlinelab-bootconf/offlinelab-bootconf.hash
hash_file_for() {
    local config_file="$1"
    local pkg_dir
    pkg_dir="$(dirname "${BASEDIR}/${config_file}")"
    echo "${pkg_dir}/$(basename "${pkg_dir}").hash"
}

# Download the tarball at URL and append a sha256 line to hash_file.
# Skips silently if the tarball name is already listed.
update_hash() {
    local hash_file="$1" url="$2" tarball="$3"
    if grep -q " ${tarball}$" "${hash_file}" 2>/dev/null; then
        return 0
    fi
    printf "  fetching hash for %s (via buildbox)..." "${tarball}" >&2
    local hash
    # Compute hash on the buildbox: GitHub tarballs are non-reproducible and
    # differ between machines. The buildbox is the authoritative build host.
    hash="$(bin/buildbox.sh ssh "curl -fsSL '${url}' | sha256sum | cut -d' ' -f1" 2>/dev/null | tr -d '[:space:]')"
    if [[ -z "${hash}" ]]; then
        printf " FAILED (buildbox fetch error)\n" >&2
        return 1
    fi
    printf "sha256  %s  %s\n" "${hash}" "${tarball}" >>"${hash_file}"
    printf " done\n" >&2
}

print_row() {
    local label="$1" pinned="$2" latest="$3" updated="$4"
    local marker
    if [[ "$updated" == "true" ]]; then
        marker=" => updated"
    elif [[ "$pinned" == "$latest" ]]; then
        marker=" (up to date)"
    elif [[ "$latest" == "(unavailable)" ]]; then
        marker=" (could not fetch upstream)"
    else
        marker=" => UPDATE AVAILABLE"
    fi
    printf "%-20s  %-44s  %-44s%s\n" "$label" "$pinned" "$latest" "$marker"
}

printf "\n%-20s  %-44s  %-44s\n" "REPO" "PINNED" "LATEST"
printf -- "%-20s  %-44s  %-44s\n" "--------------------" "--------------------------------------------" "--------------------------------------------"

for entry in "${TAG_REPOS[@]}"; do
    [[ "$entry" == \#* ]] && continue
    IFS=: read -r repo config_file config_key <<<"$entry"
    pinned="$(pinned_version "$config_file" "$config_key")"
    latest="$(latest_tag "$repo")"
    updated=false
    if [[ "$UPDATE" == "true" && "$latest" != "(unavailable)" && "$pinned" != "$latest" ]]; then
        update_version "$config_file" "$pinned" "$latest"
        hf="$(hash_file_for "$config_file")"
        url="https://github.com/${ORG}/${repo}/archive/refs/tags/${latest}.tar.gz"
        tarball="offlinelab-${repo}-${latest}.tar.gz"
        [[ -f "$hf" ]] && update_hash "$hf" "$url" "$tarball"
        updated=true
    fi

    print_row "$repo" "$pinned" "$latest" "$updated"
done

for entry in "${COMMIT_REPOS[@]}"; do
    [[ "$entry" == \#* ]] && continue
    IFS=: read -r repo branch config_file config_key <<<"$entry"
    pinned="$(pinned_version "$config_file" "$config_key")"
    latest="$(latest_commit "$repo" "$branch")"
    updated=false
    if [[ "$UPDATE" == "true" && "$latest" != "(unavailable)" && "$pinned" != "$latest" ]]; then
        update_version "$config_file" "$pinned" "$latest"
        hf="$(hash_file_for "$config_file")"
        url="https://github.com/${ORG}/${repo}/archive/${latest}.tar.gz"
        tarball="offlinelab-${repo}-${latest}.tar.gz"
        [[ -f "$hf" ]] && update_hash "$hf" "$url" "$tarball"
        updated=true
    fi
    print_row "${repo}@${branch}" "$pinned" "$latest" "$updated"
done

printf "\n"
if [[ "$UPDATE" == "true" ]]; then
    printf "Remember to run <pkg>-dirclean before rebuilding updated packages.\n\n"
fi
