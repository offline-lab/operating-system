# Build Scripts Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Harden all `bin/` scripts with proper tool existence checks, consistent error handling, shellcheck/shfmt compliance, and human-readable structure. Then improve README buildbox VM instructions.

**Architecture:** Each script gets a `require_tools` function call at entry that validates all external dependencies before any work begins. Logging is unified. All scripts pass `shellcheck -s bash` and `shfmt -i 4 -ci -bn` cleanly.

**Tech Stack:** Bash 4+, shellcheck 0.11+, shfmt 3.x

---

## Behavioral Guarantees

These invariants MUST hold after every task. If a change violates any of these, it's wrong.

1. **Same exit codes.** Scripts that succeeded before must still succeed. Scripts that failed must still fail (possibly with a better error message).
2. **Same command sequence.** The actual `make`, `docker`, `ssh`, `rsync`, etc. invocations must remain identical — same flags, same arguments, same order.
3. **Same stdout/stderr for build output.** Build tools (make, etc.) output goes to the same fd it always did. Adding `log "Starting..."` markers on stderr is fine. Swallowing or redirecting build tool output is NOT fine.
4. **Same conditional branches.** If a block was guarded by `if [[ -f X ]]`, the same guard must exist. No silently removing conditionals.
5. **No new silent failures.** The `|| true` pattern is only acceptable where the original had it. New `|| true` on previously-unguarded commands changes behavior.
6. **Streaming output preserved.** `cmd_build` in buildbox.sh streams build output in real-time. Do NOT buffer to a temp file.

Every task below includes a "Behavioral diff" section that calls out exactly what changes in runtime behavior vs the original.

---

## Audit Findings

### shellcheck issues (must fix)

| File | Line | Code | Issue |
|------|------|------|-------|
| `bin/builder.sh` | 139 | SC2046 | Unquoted `$(...)` in awk expression |
| `bin/buildbox.sh` | 40 | SC2034 | `REMOTE_BUILDROOT` assigned but never used |
| `bin/buildbox.sh` | 59 | SC2029 | `${REMOTE_HOST}` expands client-side in ssh |
| `bin/verify.sh` | 43 | SC2329 | `assert_dir` defined but never called (false positive — called directly) |
| `bin/verify.sh` | 65 | SC2312 | `file` command inside `$(...)` masks return value |
| `bin/verify.sh` | 91 | SC2329 | `cleanup` defined but never called (false positive — used in trap) |

### shfmt issues (must fix)

All files have minor formatting drift: redirect spacing `> file` vs `>file`, case indentation, arithmetic spacing `$(( a - b ))` vs `$((a - b))`.

### Missing tool existence checks (critical)

These scripts use external tools without checking they exist:

| Script | Tools used without checks |
|--------|--------------------------|
| `bin/build.sh` | `nproc`, `mountpoint`, `blkid`, `mkfs.ext4`, `mount`, `ccache`, `make`, `pigz`, `sudo` |
| `bin/build-native.sh` | `nproc`, `ccache`, `make`, `pigz` |
| `bin/builder.sh` | `docker`, `git`, `sysctl`, `truncate`, `awk` |
| `bin/buildbox.sh` | `ssh`, `rsync`, `scp`, `hdiutil`, `utmctl` (partial — `cmd_create` checks but others don't) |
| `bin/clean.sh` | `make` |
| `bin/verify.sh` | `fdisk`, `losetup`, `mount`, `cpio`, `file` (all guarded by `command -v` — OK) |

### Other issues

- `bin/buildbox.sh:453`: `PIPESTATUS[0]` inside piped `while` — unreliable, always 0. Must fix but preserve streaming.
- `bin/builder.sh:139`: Complex awk expression for memory calc is fragile
- `bin/clean.sh`: No error message if `/buildroot` doesn't exist
- `bin/build.sh:26`: `sudo mount` silently fails — should be explicit about binfmt requirement
- No consistent logging in `build.sh`, `build-native.sh`, `clean.sh`

---

## Task 1: Create shared library with `require_tools` and logging

**Files:**
- Create: `bin/lib/common.sh`

**Behavioral diff:** None — new file, not yet sourced.

**Step 1: Write the shared library**

```bash
#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# Shared functions for build scripts.
# Source this file, do not execute it directly.
#

if [[ -z "${_COMMON_SH_LOADED:-}" ]]; then
    readonly _COMMON_SH_LOADED=1
else
    return 0
fi

function log() {
    printf '\e[1;32m>>>\e[0m %s\n' "${*}"
}

function log_err() {
    printf '\e[1;31m!!!\e[0m %s\n' "${*}" >&2
}

function log_dim() {
    printf '\e[0;90m    %s\e[0m\n' "${*}"
}

function require_tools() {
    local missing=0

    for tool in "${@}"; do
        if ! command -v "${tool}" &>/dev/null; then
            log_err "Required tool not found: ${tool}"
            missing=$((missing + 1))
        fi
    done

    if [[ "${missing}" -gt 0 ]]; then
        log_err "Install the ${missing} missing tool(s) above, then re-run."
        return 1
    fi
}
```

**Step 2: Verify shellcheck passes**

Run: `shellcheck -s bash bin/lib/common.sh`
Expected: No errors

---

## Task 2: Harden `bin/build.sh`

**Files:**
- Modify: `bin/build.sh`
- Depends on: Task 1

**Behavioral diff:**

| Aspect | Before | After | Acceptable? |
|--------|--------|-------|-------------|
| Missing tool failure | Fails at point of use: `bash: nproc: command not found` | Fails at entry: `Required tool not found: nproc` | Yes — same exit code (1), better message |
| `binfmt_misc` mount | `|| true` — silently swallows failure | Logs outcome, still continues on failure | Yes — still non-fatal, just visible |
| Phase markers | None | `log "Loading defconfig"` etc. on stderr | Yes — build tool stdout untouched |

**What does NOT change:** All `make` invocations identical. Same flags, same order. Same `mount`/`mkfs.ext4`/`blkid` logic. Same `pigz` and `cp` at the end.

**Step 1: Rewrite `bin/build.sh`**

```bash
#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# Build script — runs inside the Docker container.
# Invoked by builder.sh or manually inside the container.
#
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

require_tools nproc mountpoint blkid mkfs.ext4 mount ccache make pigz date cp

NPROC="$(nproc)"
export MAKEFLAGS="-j${NPROC}"

log "Starting build with ${NPROC} CPUs"

if [[ -f /buildroot/output.img ]]; then
    if ! mountpoint -q /buildroot/output 2>/dev/null; then
        mkdir -p /buildroot/output
        if ! blkid /buildroot/output.img &>/dev/null; then
            log "Formatting output disk image"
            mkfs.ext4 -F -q /buildroot/output.img
        fi
        mount -o loop /buildroot/output.img /buildroot/output
    fi
fi

if [[ ! -d /buildroot/.ccache ]]; then
    mkdir -p /buildroot/.ccache
    chmod 0775 /buildroot/.ccache
    chown -R builder:builder /buildroot/.ccache
    ccache --max-size=15G
fi

if sudo mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null; then
    log_dim "Mounted binfmt_misc"
else
    log_dim "binfmt_misc already mounted or unavailable"
fi

log "Loading defconfig"
make -C /buildroot BR2_EXTERNAL=/work/br2-external offlinelab_pi_zero_2w_defconfig

if [[ -f /work/.config ]]; then
    log "Merging custom .config"
    /buildroot/support/kconfig/merge_config.sh \
        -m -r -O /buildroot \
        /buildroot/.config /work/.config
fi

log "Running olddefconfig"
make -C /buildroot BR2_EXTERNAL=/work/br2-external olddefconfig

log "Building (this takes a while)..."
make -C /buildroot BR2_EXTERNAL=/work/br2-external BR2_JLEVEL="${NPROC}" -j"${NPROC}"

timestamp="$(date +%Y-%m-%d-%H%M%S)"

if [[ -e /buildroot/output/images/sdcard.img ]]; then
    log "Compressing sdcard.img"
    pigz --force -9 /buildroot/output/images/sdcard.img --stdout \
        >"/artifacts/offlinelab-sdcard-${timestamp}.img.gz"
fi

log "Copying artifacts"
cp -rv /buildroot/output/images/* /artifacts/

log "Build complete"
```

**Step 2: Verify shellcheck + shfmt**

Run: `shellcheck -s bash bin/build.sh && shfmt -d bin/build.sh`
Expected: Clean

---

## Task 3: Harden `bin/build-native.sh`

**Files:**
- Modify: `bin/build-native.sh`
- Depends on: Task 1

**Behavioral diff:**

| Aspect | Before | After | Acceptable? |
|--------|--------|-------|-------------|
| Missing tool failure | Fails at point of use | Fails at entry with `require_tools` | Yes |
| ccache init | `if ! ccache -s &>/dev/null; then ccache --max-size=15G; fi` — only sets max-size when ccache is unconfigured | Same logic preserved exactly | N/A — identical |

**What does NOT change:** The ccache conditional check is preserved as-is. All `make` invocations identical. Same `pigz` and `cp`. Same directory structure checks.

**Step 1: Rewrite `bin/build-native.sh`**

```bash
#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# Native build script for running on a Linux build host (no Docker).
# Expects: buildroot at ~/buildroot, br2-external at ~/work/br2-external
#
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

require_tools nproc ccache make pigz date cp

NPROC="$(nproc)"
export MAKEFLAGS="-j${NPROC}"

BUILDROOT="${HOME}/buildroot"
WORK="${HOME}/work"
ARTIFACTS="${HOME}/artifacts"
DL_DIR="${HOME}/downloads"
CCACHE_DIR="${HOME}/.ccache"

export BR2_DL_DIR="${DL_DIR}"

if [[ ! -d "${BUILDROOT}" ]]; then
    log_err "buildroot not found at ${BUILDROOT}"
    exit 1
fi

mkdir -p "${ARTIFACTS}" "${DL_DIR}" "${CCACHE_DIR}"

if ! ccache -s &>/dev/null; then
    ccache --max-size=15G
fi

log "Starting native build with ${NPROC} CPUs"

log "Loading defconfig"
make -C "${BUILDROOT}" BR2_EXTERNAL="${WORK}/br2-external" offlinelab_pi_zero_2w_defconfig

if [[ -f "${WORK}/.config" ]]; then
    log "Merging custom .config"
    "${BUILDROOT}/support/kconfig/merge_config.sh" \
        -m -r -O "${BUILDROOT}" \
        "${BUILDROOT}/.config" "${WORK}/.config"
fi

log "Running olddefconfig"
make -C "${BUILDROOT}" BR2_EXTERNAL="${WORK}/br2-external" olddefconfig

log "Building (this takes a while)..."
make -C "${BUILDROOT}" BR2_EXTERNAL="${WORK}/br2-external" \
    BR2_CCACHE_DIR="${CCACHE_DIR}" \
    BR2_JLEVEL="${NPROC}" -j"${NPROC}"

timestamp="$(date +%Y-%m-%d-%H%M%S)"

if [[ -e "${BUILDROOT}/output/images/sdcard.img" ]]; then
    log "Compressing sdcard.img"
    pigz --force -9 "${BUILDROOT}/output/images/sdcard.img" --stdout \
        >"${ARTIFACTS}/offlinelab-sdcard-${timestamp}.img.gz"
fi

log "Copying artifacts"
cp -rv "${BUILDROOT}/output/images/"* "${ARTIFACTS}/"

log "Build complete"
```

**Step 2: Verify shellcheck + shfmt**

Run: `shellcheck -s bash bin/build-native.sh && shfmt -d bin/build-native.sh`
Expected: Clean

---

## Task 4: Harden `bin/builder.sh`

**Files:**
- Modify: `bin/builder.sh`
- Depends on: Task 1

**Behavioral diff:**

| Aspect | Before | After | Acceptable? |
|--------|--------|-------|-------------|
| Missing docker/git | Fails at point of use with cryptic error | Fails at entry with `require_tools` | Yes |
| Memory calculation | Inline awk with nested `$(...)` (SC2046) | Pre-computed variable, same formula | Yes — identical value |
| CPU count | `sysctl -n hw.ncpu 2>/dev/null \|\| nproc 2>/dev/null \|\| echo 4` | Same three-tier fallback | N/A — identical |
| Logger | `log::formatter` with colors/levels/timestamps | **Preserved as-is** — builder.sh keeps its own logger | N/A — no change |

**What does NOT change:** The fancy `log::formatter`/`log::info`/`log::error` system stays. `require_tools` is the only addition from common.sh. All `docker run`/`docker build`/`docker exec` calls identical. Same volume mounts, same env vars.

**Step 1: Add source and require_tools**

At the top of the file, after `set -e -u -o pipefail`, add:

```bash
# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"
```

In `build::main`, after the `.env` source block (line 309), add:

```bash
if ! build::is_docker; then
    require_tools docker git awk
fi
```

**Step 2: Fix the memory calculation (line 139)**

Replace the inline awk:

```bash
--memory "$(awk 'BEGIN{printf "%.0fg", '$(sysctl -n hw.memsize 2>/dev/null || echo 8589934592)'/1073741824 * 0.9}')"
```

With pre-computed variables (same math, just readable):

```bash
local mem_bytes
mem_bytes="$(sysctl -n hw.memsize 2>/dev/null || echo 8589934592)"
local mem_gb
mem_gb="$(awk -v mem="${mem_bytes}" 'BEGIN { printf "%.0fg", mem / 1073741824 * 0.9 }')"
```

Then use `--memory "${mem_gb}"` in the run_arguments array.

**Step 3: Add truncate to require_tools**

Before the truncate call (line 323), add `require_tools truncate`. Since `require_tools` only fails on missing tools, calling it with a tool that exists is a no-op.

**Step 4: Run shellcheck + shfmt**

Run: `shellcheck -s bash bin/builder.sh && shfmt -d bin/builder.sh`
Expected: Clean

---

## Task 5: Harden `bin/buildbox.sh`

**Files:**
- Modify: `bin/buildbox.sh`
- Depends on: Task 1

**Behavioral diff:**

| Aspect | Before | After | Acceptable? |
|--------|--------|-------|-------------|
| Logging | Local `log`/`log_err`/`log_dim` definitions | Source from `lib/common.sh` (identical functions) | Yes — same output |
| `REMOTE_BUILDROOT` | Declared but unused (SC2034) | Removed | Yes — dead code |
| `cmd_build` PIPESTATUS | `PIPESTATUS[0]` unreliable after pipe — shows wrong exit code | Drop `${rc}` display, just say "Build failed" | Yes — old code showed wrong code anyway |
| `cmd_build` streaming | Real-time streaming of `>>>` lines | **PRESERVED** — same pipe pattern, same `while read` | N/A — identical UX |
| Missing ssh/rsync/scp | Fails at point of use | Fails at cmd entry with `require_tools` | Yes |
| `bb_ssh` SC2029 | shellcheck info note | Add `# shellcheck disable=SC2029` — client-side expansion IS the intent | Yes — suppress false positive |

**What does NOT change:** All `bb_ssh`, `bb_rsync`, `bb_scp` calls identical. Same SSH options. Same VM create/destroy flow. Same cloud-init generation. Same UTM plist. `cmd_build` still streams output in real-time.

**Step 1: Source common.sh, remove duplicate log functions**

Replace the logging block (lines 50-52):
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

**Step 2: Remove unused `REMOTE_BUILDROOT`**

Delete line 40: `REMOTE_BUILDROOT="/home/builder/buildroot"`

**Step 3: Fix `bb_ssh` SC2029**

Add `# shellcheck disable=SC2029` above the `bb_ssh` function. The expansion IS intentional — we want the local variable expanded before ssh sends it to the remote host.

**Step 4: Fix `cmd_build` — preserve streaming, drop broken PIPESTATUS**

Replace:
```bash
if ! bb_ssh "bash ${REMOTE_WORK}/bin/build-native.sh" 2>&1 | while IFS= read -r line; do
    if [[ "${line}" == *">>>"* ]]; then
        log_dim "${line}"
    fi
done; then
    local rc=${PIPESTATUS[0]}
    log_err "Build failed (exit code ${rc})"
    log_err "Full log: ssh builder@${REMOTE_HOST} cat /home/builder/build.log"
    return 1
fi
```

With (same streaming, just drop the unreliable `${rc}` display):
```bash
if ! bb_ssh "bash ${REMOTE_WORK}/bin/build-native.sh" 2>&1 | while IFS= read -r line; do
    if [[ "${line}" == *">>>"* ]]; then
        log_dim "${line}"
    fi
done; then
    log_err "Build failed"
    log_err "Full log: ssh builder@${REMOTE_HOST} cat /home/builder/build.log"
    return 1
fi
```

The `if !` + `set -o pipefail` correctly detects the failure. The only thing lost is the wrong exit code that was displayed — which was wrong anyway.

**Step 5: Add `require_tools` to cmd functions**

- `cmd_sync`: add `require_tools ssh rsync scp` at top
- `cmd_build`: add `require_tools ssh rsync date` at top
- `cmd_verify`: add `require_tools ssh` at top
- `cmd_fetch`: add `require_tools rsync` at top
- `cmd_ssh`: add `require_tools ssh` at top
- `create_cidata_iso`: add `require_tools hdiutil` at top

`cmd_create` and `cmd_destroy` already check their tools — leave as-is.

**Step 6: Verify shellcheck + shfmt**

Run: `shellcheck -s bash bin/buildbox.sh && shfmt -d bin/buildbox.sh`
Expected: Clean

---

## Task 6: Harden `bin/clean.sh`

**Files:**
- Modify: `bin/clean.sh`
- Depends on: Task 1

**Behavioral diff:**

| Aspect | Before | After | Acceptable? |
|--------|--------|-------|-------------|
| Missing `/buildroot` | `make` fails: `make: *** No rule. Stop.` | Clear error: `/buildroot not found — are you inside the builder container?` | Yes — same exit code, better message |

**What does NOT change:** The `make -C /buildroot distclean` invocation is identical.

**Step 1: Rewrite `bin/clean.sh`**

```bash
#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

require_tools make

if [[ ! -d /buildroot ]]; then
    log_err "/buildroot not found — are you inside the builder container?"
    exit 1
fi

log "Running buildroot distclean"
make -C /buildroot distclean
```

**Step 2: Verify shellcheck + shfmt**

Run: `shellcheck -s bash bin/clean.sh && shfmt -d bin/clean.sh`
Expected: Clean

---

## Task 7: Harden `bin/verify.sh`

**Files:**
- Modify: `bin/verify.sh`
- Depends on: Task 1

**Behavioral diff:**

| Aspect | Before | After | Acceptable? |
|--------|--------|-------|-------------|
| Missing cpio/file | Fails mid-run when extraction fails | Fails at entry with `require_tools` | Yes |
| `assert_static` output | `file binary \| grep -q` then `file binary \| cut` (calls `file` twice) | Calls `file` once, stores result, checks with `[[ ]]` | Yes — same pass/fail, one fewer subprocess |
| SC2329 warnings | None suppressed | Add `# shellcheck disable=SC2329` above `cleanup` and `assert_dir` | Yes — false positives (both are used) |

**What does NOT change:** All assertion functions identical. Same pass/fail/skip counters. Same section structure. Same artifact location logic. Same mount/loop logic. All conditional `command -v` guards for fdisk/losetup/mount preserved.

**Step 1: Add source and require_tools**

After `set -e -u -o pipefail`, add:

```bash
# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

require_tools cpio file find
```

**Step 2: Fix SC2329 — suppress false positives**

Add `# shellcheck disable=SC2329` above `assert_dir` and `cleanup` function definitions.

**Step 3: Fix SC2312 — assert_static**

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

With:
```bash
# shellcheck disable=SC2329
function assert_static() {
    local binary="${1}" desc="${2:-${1} is static}"
    local file_type
    file_type="$(file "${binary}" 2>/dev/null | cut -d: -f2-)" || true
    if [[ "${file_type}" == *"statically linked"* ]]; then
        pass "${desc}"
    else
        fail "${desc} — ${file_type}"
    fi
}
```

Same pass/fail logic. `file` called once instead of twice. The `|| true` handles the case where `file` itself fails (e.g., binary doesn't exist) — `file_type` will be empty, which means the `[[ ]]` test fails, which correctly calls `fail`. Same outcome as original.

**Step 4: Verify shellcheck + shfmt**

Run: `shellcheck -s bash bin/verify.sh && shfmt -d bin/verify.sh`
Expected: Clean

---

## Task 8: Run shfmt on all scripts

**Files:**
- Modify: all `bin/*.sh`, `bin/lib/*.sh`

**Step 1: Format all scripts**

Run: `shfmt -i 4 -ci -bn -w bin/*.sh bin/lib/*.sh`

**Step 2: Verify no diff**

Run: `shfmt -d bin/*.sh bin/lib/*.sh`
Expected: No output (clean)

---

## Task 9: Run shellcheck on all scripts — final gate

**Files:**
- Verify: all `bin/*.sh`, `bin/lib/*.sh`

**Step 1: Run full shellcheck**

Run: `shellcheck -s bash bin/lib/common.sh bin/build.sh bin/build-native.sh bin/builder.sh bin/buildbox.sh bin/clean.sh bin/verify.sh`
Expected: Clean (zero exit code)

---

## Task 10: Improve README buildbox VM instructions

**Files:**
- Modify: `README.md`

**Behavioral diff:** Documentation only — no code changes.

**Step 1: Rewrite the "Native build (buildbox VM)" section**

Replace the existing `### Native build (buildbox VM)` section and the paragraph above it with:

```markdown
### Prerequisites

- **Docker path:** Docker Desktop with `linux/arm64` platform support (macOS), ~15GB disk
- **VM path:** macOS with Apple Silicon, [UTM](https://mac.getutm.app/), ~60GB disk, 24GB+ RAM recommended
- **Native Linux:** arm64 Debian host with build tools installed

### Quick start (Docker)

```bash
cp env.example .env
cp config.example .config

bin/builder.sh --build-docker
bin/builder.sh --build

# Or open a shell in the build container
bin/builder.sh --shell
```

### Native build (buildbox VM)

Builds on a native arm64 Debian VM via UTM. No Docker emulation overhead.
Recommended for regular development on Apple Silicon macOS.

#### One-time setup

```bash
# 1. Generate SSH key for the buildbox
ssh-keygen -t ecdsa -f .ssh/builder -N ''

# 2. Create and provision the VM (~5 min first run)
bin/buildbox.sh create
```

The `create` command downloads a Debian 13 arm64 cloud image, creates a UTM VM
with 8 vCPUs and 24GB RAM, provisions it via cloud-init, and outputs the VM IP.

```bash
# 3. Add the VM IP to /etc/hosts (optional but convenient)
echo "10.0.0.XXX  buildbox" | sudo tee -a /etc/hosts
```

#### Building

```bash
bin/buildbox.sh                # full pipeline: sync + build + verify + fetch
bin/buildbox.sh build          # sync + build only
bin/buildbox.sh sync           # push code to buildbox
bin/buildbox.sh verify         # run verification
bin/buildbox.sh fetch          # download artifacts
```

#### Interactive access

```bash
bin/buildbox.sh ssh                        # drop into shell
bin/buildbox.sh ssh "htop"                 # run a command
```

#### Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `BUILDBOX_HOST` | auto-detect from UTM or `/etc/hosts` | Override buildbox address |
| `BUILDBOX_VM_NAME` | `Buildbox` | Override VM name in UTM |

#### Troubleshooting

- **Cannot resolve buildbox address**: Set `BUILDBOX_HOST=<ip>` or add `buildbox` to `/etc/hosts`
- **SSH connection refused**: VM may still be booting. Check with `utmctl status Buildbox`
- **Build fails with missing tools**: SSH in (`bin/buildbox.sh ssh`) and install manually, or destroy and re-create
- **Out of disk space in VM**: SSH in, run `df -h`. Clean build output: `rm -rf ~/buildroot/output`
- **Want to start fresh**: `bin/buildbox.sh destroy && bin/buildbox.sh create`

#### Teardown

```bash
bin/buildbox.sh destroy        # stop and delete the VM
```
```

**Step 2: Verify markdown**

Read the full README back and confirm:
- "Quick start (Docker)" still works
- "Native build (buildbox VM)" is now more detailed with setup steps
- Table of contents / structure makes sense
- No duplicate content with the "Write to SD card" section below

---

## Summary

| Task | File(s) | What | Behavior changed? |
|------|---------|------|--------------------|
| 1 | `bin/lib/common.sh` | Shared library: `log`, `log_err`, `log_dim`, `require_tools` | New file |
| 2 | `bin/build.sh` | Tool checks, phase logging, binfmt visibility | Error messages only |
| 3 | `bin/build-native.sh` | Tool checks, phase logging | Error messages only |
| 4 | `bin/builder.sh` | Fix SC2046, add require_tools, fix memory calc | Error messages + awk readability |
| 5 | `bin/buildbox.sh` | Source common.sh, drop dead var, fix PIPESTATUS msg, add tool checks | Error messages + removed wrong exit code display |
| 6 | `bin/clean.sh` | Tool check, existence guard, log message | Error messages only |
| 7 | `bin/verify.sh` | Fix SC2312, add require_tools, suppress false positives | Error messages only |
| 8 | All | shfmt pass | Formatting only |
| 9 | All | shellcheck final verification | Verification only |
| 10 | `README.md` | Better buildbox VM instructions | Docs only |
