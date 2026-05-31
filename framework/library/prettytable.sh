#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

export char_top_left="┌"
export char_horizontal="─"
export char_vertical="│"
export char_bottom_left="└"
export char_bottom_right="┘"
export char_top_right="┐"
export char_vertical_horizontal_left="├"
export char_vertical_horizontal_right="┤"
export char_vertical_horizontal_top="┬"
export char_vertical_horizontal_bottom="┴"
export char_vertical_horizontal="┼"

function prettytable::prettify_lines() {
    { cat /dev/stdin || true; } |
        sed -e "s@^@${char_vertical}@;s@\$@	@;s@	@	${char_vertical}@g"
}

function prettytable::prettify_header() {
    { cat /dev/stdin || true; } |
        sed -e "s@^@${char_vertical}@;s@\$@	@;s@	@	${char_vertical}@g"
}

function prettytable::fix_border_lines() {
    sed -e "1s@ @${char_horizontal}@g;3s@ @${char_horizontal}@g;\$s@ @${char_horizontal}@g" </dev/stdin
}

function prettytable::table() {
    [[ "${#}" -ne 1 ]] && return 2

    local input header cols body

    cols="${1}"
    input="$(cat -)"
    header="$(printf '%s\n' "${input}" | head -n1)"
    body="$(printf '%s\n' "${input}" | tail -n+2)"

    {
        printf '%s' "${char_top_left}"

        for _ in $(seq 2 "${cols}" || true); do
            printf '\t%s' "${char_vertical_horizontal_top}"
        done

        printf '\t%s\n' "${char_top_right}"
        printf '%s\n' "${header}" | prettytable::prettify_lines || true

        printf '%s' "${char_vertical_horizontal_left}"

        for _ in $(seq 2 "${cols}" || true); do
            printf '\t%s' "${char_vertical_horizontal}"
        done

        printf '\t%s\n' "${char_vertical_horizontal_right}"
        printf '%s\n' "${body}" | prettytable::prettify_lines || true

        printf '%s' "${char_bottom_left}"

        for _ in $(seq 2 "${cols}" || true); do
            printf '\t%s' "${char_vertical_horizontal_bottom}"
        done

        printf '\t%s\n' "${char_bottom_right}"

    } | column -t -s $'\t' | prettytable::fix_border_lines || true
}

################################################################################
# EOF                                                                          #
################################################################################
