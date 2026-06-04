#!/usr/bin/env bats

load "../../bin/framework"
import files

#
# files::append_unique_lines
#

@test "files::append_unique_lines: appends lines from src to empty dst" {
    local src dst
    src="$(mktemp -t src-XXXX)"
    dst="$(mktemp -t dst-XXXX)"

    printf 'key-a\nkey-b\n' > "${src}"
    > "${dst}"

    run files::append_unique_lines "${src}" "${dst}"
    [[ "${status}" -eq 0 ]]
    [[ "$(wc -l < "${dst}")" -eq 2 ]]
    grep -qxF "key-a" "${dst}"
    grep -qxF "key-b" "${dst}"

    rm -f "${src}" "${dst}"
}

@test "files::append_unique_lines: skips lines already present in dst" {
    local src dst
    src="$(mktemp -t src-XXXX)"
    dst="$(mktemp -t dst-XXXX)"

    printf 'key-a\nkey-b\n' > "${src}"
    printf 'key-a\n' > "${dst}"

    run files::append_unique_lines "${src}" "${dst}"
    [[ "${status}" -eq 0 ]]
    [[ "$(wc -l < "${dst}")" -eq 2 ]]

    rm -f "${src}" "${dst}"
}

@test "files::append_unique_lines: does not add duplicates on repeated calls" {
    local src dst
    src="$(mktemp -t src-XXXX)"
    dst="$(mktemp -t dst-XXXX)"

    printf 'key-a\nkey-b\n' > "${src}"
    > "${dst}"

    files::append_unique_lines "${src}" "${dst}"
    files::append_unique_lines "${src}" "${dst}"

    [[ "$(wc -l < "${dst}")" -eq 2 ]]

    rm -f "${src}" "${dst}"
}

@test "files::append_unique_lines: skips blank lines and comments" {
    local src dst
    src="$(mktemp -t src-XXXX)"
    dst="$(mktemp -t dst-XXXX)"

    printf '# this is a comment\n\nkey-a\n' > "${src}"
    > "${dst}"

    run files::append_unique_lines "${src}" "${dst}"
    [[ "${status}" -eq 0 ]]
    [[ "$(wc -l < "${dst}")" -eq 1 ]]
    grep -qxF "key-a" "${dst}"

    rm -f "${src}" "${dst}"
}

@test "files::append_unique_lines: creates dst if it does not exist" {
    local src dst
    src="$(mktemp -t src-XXXX)"
    dst="/tmp/test_files_dst_$$"

    printf 'key-a\n' > "${src}"
    rm -f "${dst}"

    run files::append_unique_lines "${src}" "${dst}"
    [[ "${status}" -eq 0 ]]
    [[ -f "${dst}" ]]

    rm -f "${src}" "${dst}"
}

@test "files::append_unique_lines: returns 1 if src does not exist" {
    run files::append_unique_lines /does/not/exist /tmp/dst-$$
    [[ "${status}" -eq 1 ]]
}

@test "files::append_unique_lines: returns 2 with wrong arity" {
    run files::append_unique_lines only-one-arg
    [[ "${status}" -eq 2 ]]
}
