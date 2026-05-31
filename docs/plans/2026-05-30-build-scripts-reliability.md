# Build Scripts Reliability Plan

**Supersedes:** `docs/plans/2026-05-24-build-scripts-hardening.md`

**Goal:** Fix the real bugs in the build scripts, complete the `require_tools` migration, and
ensure shellcheck/shfmt pass. Nothing in this plan changes build logic — `make` flags, Docker
arguments, SSH options, and RAUC/verification logic are treated as read-only.

**Current state:**
- `bin/lib/common.sh` — done
- `bin/build.sh` — done (sources common.sh, require_tools, phase logging)
- All other scripts — not yet touched

---

## Invariants — must hold after every task

1. **Same exit codes.** Commands that succeeded before still succeed; failures still fail.
2. **Same command sequence.** Every `make`, `docker`, `ssh`, `rsync`, `scp` invocation is
   identical — same flags, same order, same arguments.
3. **Same build output.** Build tool stdout/stderr is unchanged. Adding `log "..."` markers
   on stderr is fine. Swallowing build tool output is not.
4. **Same conditional branches.** Every `if [[ -f X ]]` guard is preserved exactly.
5. **No new `|| true` on previously-unguarded commands.** Only add `|| true` where the
   original already had it, or on cosmetic ops (log calls, cleanup in traps).
6. **Streaming preserved.** `cmd_build` in buildbox.sh streams build output in real-time.
   Do not buffer to a temp file.

---

## Audit

### Critical bugs (will silently break)

| File | Line | Issue |
|------|------|-------|
| `bin/buildbox.sh` | 135, 157, 396 | `((attempt++))` with `set -e` exits on first iteration when `attempt=0` — post-increment yields 0, which is a non-zero exit code to bash |
| `bin/buildbox.sh` | 76 | `bb_rsync` passes `-e "ssh ${SSH_OPTS[*]}"` — word-splits the array; safe with current values but breaks if any option ever contains a space |

### Correctness issues (not silent, but unfriendly)

| File | Line | Issue |
|------|------|-------|
| `bin/build-native.sh` | — | No `source common.sh`, no `require_tools`; tools fail at point of use with cryptic bash errors |
| `bin/buildbox.sh` | 52 | `REMOTE_BUILDROOT` declared but never used (SC2034) |
| `bin/buildbox.sh` | 62–64 | Duplicate local `log`/`log_err`/`log_dim` — identical to `common.sh`; two sources of truth for the same functions |
| `bin/buildbox.sh` | 471 | `PIPESTATUS[0]` inside piped `while` is always 0; `if !` + pipefail detects the failure correctly but the displayed exit code is always wrong |
| `bin/builder.sh` | 151 | SC2046: unquoted `$(sysctl ...)` inside awk expression; word-splits if result contains spaces (unlikely but fragile) |
| `bin/builder.sh` | — | No `require_tools`; `docker`/`git`/`awk`/`truncate` fail at point of use |
| `bin/clean.sh` | — | No `/buildroot` guard; `make` fails with a confusing "no rule" error instead of "not inside container" |
| `bin/clean.sh` | — | No `require_tools`, no `source common.sh` |
| `bin/verify.sh` | 72–78 | `assert_static` calls `file` twice, masking its exit code (SC2312) |
| `bin/verify.sh` | 106 | SC2329 false positive on `cleanup` (used via `trap`) |

### shfmt drift

`builder.sh` and `buildbox.sh` have significant formatting drift (86 and 52 changed lines
respectively). `build-native.sh` and `verify.sh` have minor drift. Apply shfmt after all
other changes are done.

---

## Task 1: Fix `((attempt++))` with `set -e` in buildbox.sh

**Files:** `bin/buildbox.sh`

**The bug:** `((expr))` in bash exits non-zero when the expression evaluates to 0. With
post-increment (`attempt++`), the old value (0) is the result on the first iteration.
Combined with `set -e`, this exits the script immediately after the first failed SSH attempt
— meaning the wait loop never actually waits.

**What changes:** Three `((attempt++))` → `attempt=$(( attempt + 1 ))` replacements.
Nothing else.

**What does NOT change:** SSH options, sleep durations, loop conditions, max_attempts defaults.

**Replacements:**

1. `wait_for_ssh` (line ~135):
   ```bash
   # Before
   ((attempt++))
   # After
   attempt=$(( attempt + 1 ))
   ```

2. `wait_for_cloudinit` (line ~157):
   ```bash
   # Before
   ((attempt++))
   # After
   attempt=$(( attempt + 1 ))
   ```

3. IP wait loop in `cmd_create` (line ~396):
   ```bash
   # Before
   ((attempts++))
   # After
   attempts=$(( attempts + 1 ))
   ```

**Verify:** `shellcheck -s bash bin/buildbox.sh` — should show no new warnings.
Confirm the three substitutions are the only diff: `git diff bin/buildbox.sh`.

---

## Task 2: Fix `bb_rsync` array expansion in buildbox.sh

**Files:** `bin/buildbox.sh`

**The bug:** `-e "ssh ${SSH_OPTS[*]}"` word-splits the SSH_OPTS array. The current options
(`-F /dev/null -i ... -o ...`) don't contain spaces, so this works today. But it will silently
break if a future option value contains a space (e.g., a path with a space).

**What changes:** The `-e` argument to rsync uses a properly quoted array.

**Before (line ~76):**
```bash
function bb_rsync() {
    SSH_AUTH_SOCK=/dev/null rsync -a --delete \
        -e "ssh ${SSH_OPTS[*]}" \
        "${@}"
}
```

**After:**
```bash
function bb_rsync() {
    SSH_AUTH_SOCK=/dev/null rsync -a --delete \
        -e "ssh ${SSH_OPTS[*]@Q}" \
        "${@}"
}
```

Wait — `@Q` would add shell quoting around each element, which rsync passes to the shell.
Actually the cleanest fix here that doesn't change the behavior:

```bash
function bb_rsync() {
    local ssh_cmd
    ssh_cmd="ssh $(printf '%q ' "${SSH_OPTS[@]}")"
    SSH_AUTH_SOCK=/dev/null rsync -a --delete \
        -e "${ssh_cmd}" \
        "${@}"
}
```

`printf '%q'` shell-quotes each element so rsync's `-e` gets a properly-escaped command string.
This is equivalent to what `${SSH_OPTS[*]}` produces for option values without spaces, but
safe for values with spaces.

**What does NOT change:** The rsync flags (`-a --delete`), the `SSH_AUTH_SOCK=/dev/null`,
the SSH options themselves, all call sites.

**Verify:** `shellcheck -s bash bin/buildbox.sh` clean. Confirm diff is only `bb_rsync`.

---

## Task 3: Complete buildbox.sh cleanup

**Files:** `bin/buildbox.sh`

**What changes:** Four independent cleanups. None touch command logic.

**3a — Source common.sh, remove duplicate log functions**

Replace lines 62–64:
```bash
function log()     { printf '\e[1;32m>>>\e[0m %s\n' "${*}"; }
function log_err() { printf '\e[1;31m!!!\e[0m %s\n' "${*}" >&2; }
function log_dim() { printf '\e[0;90m    %s\e[0m\n' "${*}"; }
```

With:
```bash
# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"
```

The functions in `common.sh` are byte-for-byte identical. No behavior change.

**3b — Remove dead `REMOTE_BUILDROOT`**

Delete line 52: `REMOTE_BUILDROOT="/home/builder/buildroot"`

**3c — Fix PIPESTATUS display in `cmd_build`**

Replace:
```bash
        local rc=${PIPESTATUS[0]}
        log_err "Build failed (exit code ${rc})"
```

With:
```bash
        log_err "Build failed"
```

The `if !` + `set -o pipefail` already detects failure correctly. The `rc` variable was always
0 because `PIPESTATUS` inside `while` captures the while's own exit code, not ssh's. Dropping
it removes a misleading display; the failure path is unchanged.

**3d — Add `# shellcheck disable=SC2029` to `bb_ssh`**

The `${@}` expanding on the client side before SSH is intentional — that's what passes the
command to the remote. Add the disable comment above `bb_ssh`.

**What does NOT change:** All `bb_ssh`, `bb_rsync`, `bb_scp` call sites. All SSH options.
All pipeline logic. The `if !` failure detection in `cmd_build`.

**Verify:** `shellcheck -s bash bin/buildbox.sh` — zero warnings/errors.
`git diff bin/buildbox.sh` — only the four targeted hunks.

---

## Task 4: Harden `bin/build-native.sh`

**Files:** `bin/build-native.sh`

**What changes:** Add `source` and `require_tools`. Replace bare `echo "ERROR:"` with
`log_err`. No changes to build logic.

**Behavioral diff:**

| Aspect | Before | After |
|--------|--------|-------|
| Missing tool | Fails at first use: `bash: nproc: command not found` | Fails at entry: `Required tool not found: nproc` |
| Error message for missing buildroot | `echo "ERROR: ..."` | `log_err "..."` (same text, consistent format) |

**After `set -e -u -o pipefail`, add:**
```bash
# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

require_tools nproc ccache make pigz date cp
```

**Replace:**
```bash
    echo "ERROR: buildroot not found at ${BUILDROOT}"
```

**With:**
```bash
    log_err "buildroot not found at ${BUILDROOT}"
```

**What does NOT change:** The ccache check (`if ! ccache -s &>/dev/null`). All three `make`
invocations and their flags. The `pigz` compress step. The `cp` step. The splash generation
block. The directory structure (`BUILDROOT`, `WORK`, `ARTIFACTS`, etc.).

**Verify:** `shellcheck -s bash bin/build-native.sh` clean.

---

## Task 5: Harden `bin/builder.sh`

**Files:** `bin/builder.sh`

**What changes:** Fix the SC2046 awk expression. Add `require_tools` before the non-Docker
path. The `log::formatter` system stays untouched.

**5a — Fix SC2046 memory calculation (line 151)**

Replace the inline nested expansion:
```bash
        --memory "$(awk 'BEGIN{printf "%.0fg", '$(sysctl -n hw.memsize 2>/dev/null || echo 8589934592)'/1073741824 * 0.9}')"
```

With pre-computed variables (same math):
```bash
        local mem_bytes
        mem_bytes="$(sysctl -n hw.memsize 2>/dev/null || echo 8589934592)"
        local mem_gb
        mem_gb="$(awk -v m="${mem_bytes}" 'BEGIN { printf "%.0fg", m / 1073741824 * 0.9 }')"
```

Then use `--memory "${mem_gb}"` in the run_arguments array.

The value is identical. The fix removes the unquoted subshell expansion that shellcheck flags.

**5b — Add `require_tools` in `build::main`**

After the `.env` source block (line ~318), in the `else` branch (non-Docker path), add:
```bash
        require_tools docker git awk truncate
```

This sources `common.sh` for `require_tools`. Add the source near the top of the file,
after `set -e -u -o pipefail`:
```bash
# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"
```

`require_tools` is a no-op from within the Docker container because `build::is_docker` gates
the else branch. The `log::formatter` functions in builder.sh are a different namespace
(`log::*`) from `common.sh` (`log`/`log_err`/`log_dim`) — no conflict.

**What does NOT change:** `log::formatter`, `log::info`, `log::error`, `log::debug`,
`log::warning`. All `docker run`/`build`/`exec` arguments. Volume mounts. Environment vars
passed to the container. The `--privileged` flag. The CPU count logic.

**Verify:** `shellcheck -s bash bin/builder.sh` clean. Run `bin/builder.sh --help` and
confirm it prints usage.

---

## Task 6: Harden `bin/clean.sh`

**Files:** `bin/clean.sh`

**What changes:** Add source, require_tools, and a guard so the error is readable.

**Behavioral diff:**

| Aspect | Before | After |
|--------|--------|-------|
| Wrong environment | `make: *** No rule to make target 'distclean'` | `!!! /buildroot not found — run inside the builder container` |

**Rewrite:**
```bash
#!/usr/bin/env bash
<banner>
# vi: ft=bash
# shellcheck shell=bash
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

require_tools make

if [[ ! -d /buildroot ]]; then
    log_err "/buildroot not found — run inside the builder container"
    exit 1
fi

log "Running buildroot distclean"
make -C /buildroot distclean
```

Keep the license banner from the current file unchanged.

**What does NOT change:** The `make -C /buildroot distclean` invocation is identical.

**Verify:** `shellcheck -s bash bin/clean.sh` clean.

---

## Task 7: Harden `bin/verify.sh`

**Files:** `bin/verify.sh`

**What changes:** Fix SC2312 in `assert_static`. Suppress SC2329 false positives. Add
`source` and `require_tools`. No changes to any test assertions.

**7a — Add source and require_tools**

After `set -e -u -o pipefail`, add:
```bash
# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

require_tools cpio find
```

Note: `file`, `fdisk`, `losetup`, `mount` are already guarded by `command -v` checks inside
the script — they are correctly NOT in `require_tools` here.

**7b — Fix `assert_static` (SC2312)**

Replace:
```bash
function assert_static() {
    local binary="${1}" desc="${2:-${1} is static}"
    if file "${binary}" 2>/dev/null | grep -q "statically linked"; then
        pass "${desc}"
    else
        fail "${desc} — $(file "${binary}" 2>/dev/null | cut -d: -f2-)"
    fi
}
```

With (calls `file` once, same pass/fail logic):
```bash
function assert_static() {
    local binary="${1}" desc="${2:-${1} is static}"
    local file_out
    file_out="$(file "${binary}" 2>/dev/null | cut -d: -f2-)" || true
    if [[ "${file_out}" == *"statically linked"* ]]; then
        pass "${desc}"
    else
        fail "${desc} — ${file_out}"
    fi
}
```

**7c — Suppress SC2329 false positives**

Add `# shellcheck disable=SC2329` above `assert_dir` (line ~51) and `cleanup` (line ~106).
Both are used — `assert_dir` is called directly in tests, `cleanup` is used via `trap`.

**What does NOT change:** All test sections. All `assert_*`, `pass`, `fail`, `skip` logic.
All mount/losetup/fdisk checks. All `command -v` guards. The counter logic. The exit code at
the end. The artifact path detection.

**Verify:** `shellcheck -s bash bin/verify.sh` — zero warnings/errors.
`git diff bin/verify.sh` — only the targeted hunks.

---

## Task 8: shfmt pass on all scripts

**Files:** All `bin/*.sh`, `bin/lib/common.sh`

Apply consistent formatting after all other changes are done.

```bash
shfmt -i 4 -ci -bn -w \
    bin/lib/common.sh \
    bin/build.sh \
    bin/build-native.sh \
    bin/builder.sh \
    bin/buildbox.sh \
    bin/clean.sh \
    bin/verify.sh
```

**What changes:** Whitespace, indentation, redirect spacing only. No logic.

**Verify:** `shfmt -d bin/*.sh bin/lib/*.sh` — no output (clean).

---

## Task 9: Final shellcheck gate

Run against all scripts to confirm zero errors/warnings:

```bash
shellcheck -s bash -x \
    bin/lib/common.sh \
    bin/build.sh \
    bin/build-native.sh \
    bin/builder.sh \
    bin/buildbox.sh \
    bin/clean.sh \
    bin/verify.sh
```

Note: use `-x` so shellcheck follows `source` directives into `lib/common.sh`. Without `-x`,
it warns SC1091 on every `source` line.

Expected: zero output, exit code 0.

---

## Summary

| Task | File(s) | Bug fixed / change | Risk |
|------|---------|-------------------|------|
| 1 | `buildbox.sh` | `((attempt++))` exits on first iteration | **Critical bug** |
| 2 | `buildbox.sh` | `bb_rsync` array word-split | Latent bug |
| 3 | `buildbox.sh` | Source common.sh, remove dead var, fix PIPESTATUS display | Cleanup |
| 4 | `build-native.sh` | Source common.sh, require_tools | Hardening |
| 5 | `builder.sh` | Fix SC2046 awk, require_tools | Hardening |
| 6 | `clean.sh` | Guard + require_tools + source | Hardening |
| 7 | `verify.sh` | Fix assert_static, SC2329 suppression, require_tools | Correctness |
| 8 | All | shfmt formatting | Cosmetic |
| 9 | All | shellcheck final gate | Verification |

**Do not touch in any task:** `make` invocations and flags, `docker run`/`build`/`exec`
arguments, volume mounts, SSH options in `buildbox.sh`, RAUC/partition/verification logic
in `verify.sh`, the `log::formatter` system in `builder.sh`.
