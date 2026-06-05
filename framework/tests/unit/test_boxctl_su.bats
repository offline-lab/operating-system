#!/usr/bin/env bats

# boxctl-su tests do not source the framework — the script is standalone.
# Tests use a temporary allowlist and mock config path via BOXCTL_SU_CONF.

BOXCTL_SU="${BATS_TEST_DIRNAME}/../../bin/boxctl-su"

setup() {
    CONF_TMPDIR="$(mktemp -d)"
    CONF_FILE="${CONF_TMPDIR}/su.conf"
    export BOXCTL_SU_CONF="${CONF_FILE}"
}

teardown() {
    rm -rf "${CONF_TMPDIR:-}"
}

##
## Argument handling
##

@test "boxctl-su: exits 1 with no arguments" {
    run bash "${BOXCTL_SU}"
    [ "${status}" -eq 1 ]
    [[ "${output}" =~ "Usage" ]]
}

##
## Config validation
##

@test "boxctl-su: exits 1 when allowlist does not exist" {
    # Run as current user — will fail on root-check first on non-root systems,
    # so skip this test when running as root
    if [[ "$(id -u)" -eq 0 ]]; then
        skip "running as root — root-check bypassed"
    fi
    run bash "${BOXCTL_SU}" true
    [ "${status}" -eq 1 ]
}

@test "boxctl-su: exits 1 when allowlist is world-writable" {
    if [[ "$(id -u)" -ne 0 ]]; then skip "requires root to test root check separately"; fi
    printf 'true\n' > "${CONF_FILE}"
    chmod 666 "${CONF_FILE}"
    run bash "${BOXCTL_SU}" true
    [ "${status}" -eq 1 ]
    [[ "${output}" =~ "world-writable" ]]
}

##
## Allowlist enforcement (run as root only)
##

@test "boxctl-su: allows a command that is in the allowlist" {
    if [[ "$(id -u)" -ne 0 ]]; then skip "requires root"; fi
    printf 'true\n' > "${CONF_FILE}"
    chmod 644 "${CONF_FILE}"
    run bash "${BOXCTL_SU}" true
    [ "${status}" -eq 0 ]
}

@test "boxctl-su: denies a command that is not in the allowlist" {
    if [[ "$(id -u)" -ne 0 ]]; then skip "requires root"; fi
    printf '# empty allowlist\n' > "${CONF_FILE}"
    chmod 644 "${CONF_FILE}"
    run bash "${BOXCTL_SU}" true
    [ "${status}" -eq 1 ]
    [[ "${output}" =~ "denied" ]]
}

@test "boxctl-su: allows command matched by full path in allowlist" {
    if [[ "$(id -u)" -ne 0 ]]; then skip "requires root"; fi
    true_path="$(command -v true)"
    printf '%s\n' "${true_path}" > "${CONF_FILE}"
    chmod 644 "${CONF_FILE}"
    run bash "${BOXCTL_SU}" true
    [ "${status}" -eq 0 ]
}

@test "boxctl-su: ignores comments and blank lines in allowlist" {
    if [[ "$(id -u)" -ne 0 ]]; then skip "requires root"; fi
    printf '# this is a comment\n\ntrue\n# another comment\n' > "${CONF_FILE}"
    chmod 644 "${CONF_FILE}"
    run bash "${BOXCTL_SU}" true
    [ "${status}" -eq 0 ]
}

@test "boxctl-su: exits 1 for a command not in PATH" {
    if [[ "$(id -u)" -ne 0 ]]; then skip "requires root"; fi
    printf 'true\n' > "${CONF_FILE}"
    chmod 644 "${CONF_FILE}"
    run bash "${BOXCTL_SU}" definitely_not_a_real_command_xyz
    [ "${status}" -eq 1 ]
    [[ "${output}" =~ "not found" ]]
}
