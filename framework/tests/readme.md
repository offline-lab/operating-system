# Tests

## Running tests

```bash
# Run all unit tests
bash tests/test_bats.sh

# Run a single test file
bats tests/unit/test_var.bats

# Dev setup (if not installed to /usr/lib/framework)
source bin/dev-setup
bash tests/test_bats.sh
```

## Unit tests

Unit tests cover the library functions using the
[bats-core](https://bats-core.readthedocs.io/en/latest/usage.html) framework.

Each test file loads the framework via `load "../../bin/framework"` and tests
individual functions in isolation. Tests follow the naming convention:

```bash
@test "<module>::<function>: <scenario>"
```

## Coverage gaps (known)

- `exit.sh` — functions call `exit`; require subshell testing
- `logging.sh` — colored output and stderr; requires capture wrappers
- `debug.sh` — trap-based; requires a running script context
- `sanity.sh` — depends on dynamically defined `sanity::check::*` functions
- `ssl.sh` / `ssh.sh` — depend on `openssl`; pending review of whether these stay
- `net::get_ip` — requires internet; must be skipped in offline test runs
- `proc::run` / `proc::runall` — call `chronic` which is pending bash port

## Test environment

Tests run in the current shell environment. The framework is loaded from
`bin/framework`, which auto-detects `FRAMEWORK_LIB_PATH` relative to the repo root.

Set `FRAMEWORK_DEPS_CHECK=false` to skip the base dependency check when running
tests without `jq` or `file` installed:

```bash
FRAMEWORK_DEPS_CHECK=false bash tests/test_bats.sh
```
