# AGENTS.md

Instructions for AI coding agents working in this repository.

---

## Monorepo structure

| Area | Path | What it is |
|---|---|---|
| **Builder** | `br2-external/`, `bin/`, `Dockerfile` | Buildroot external tree and build pipeline |
| **Framework** | `framework/` | Bash utility library and `boxctl` CLI for the OS |
| **Docs** | `docs/`, `zensical.toml` | Documentation site (Zensical static site) |

**Git:** Never run `git commit`, `git push`, or `git amend` — user handles all git operations.

---

## Builder

Produces images for Raspberry Pi (Zero 2W, 3, 4) and QEMU arm64. See [docs/build-image.md](docs/build-image.md) for the full build reference.

### Key commands

```bash
# Build on native arm64 buildbox VM (preferred)
bin/buildbox.sh build            # pi-zero-2w (default)
bin/buildbox.sh build qemu-arm64
bin/buildbox.sh all              # all boards

# Build inside Docker
bin/builder.sh build

# SSH to buildbox
SSH_AUTH_SOCK=/dev/null ssh -i .ssh/builder builder@buildbox

# Rebuild a single package after editing source
make offlinelab-framework-dirclean && make offlinelab-framework
```

### Constraints

- No binaries or third-party source committed — everything fetched at build time
- No tmpfs for state — use `/data` bind mounts
- Run `<pkg>-dirclean` after editing source files under `br2-external/` or `framework/`
- `framework/` is first-party source — edit it directly in this repo, then rebuild
- **File edits via Edit/Write tools only** — never `sed -i`, `python`, or `awk` to rewrite working-tree files

### Packages

See [docs/packages.md](docs/packages.md) for the full package reference.

Key packages: `offlinelab-base`, `offlinelab-bootconf`, `offlinelab-testing`, `offlinelab-firewall`, `offlinelab-framework`, `offlinelab-resources`, `offlinelab-portable`, `offlinelab-update`, `offlinelab-disco`.

`offlinelab-testing` is dev/test only — never enable on production builds.

### Integration test suite

The image runtime is tested by the separate **`operating-system-infra-test`** repository at `../operating-system-infra-test/` (sibling of this repo).

**Rule: every build change that installs a file, enables a service, or creates a user must have a corresponding test added or updated in that repo.**

Use the `/infra-test-update` skill to do this after any package change.

```bash
# Run tests against QEMU (auto-started):
cd ../operating-system-infra-test
bin/run-tests --board qemu-arm64 \
              --artifacts ../br2-builder/artifacts/qemu-arm64 \
              --ssh-key ../br2-builder/.ssh/builder

# Run tests for one package only:
bin/run-tests ... -k test_firewall

# Reports land in: operating-system-infra-test/reports/
```

**Test file mapping:**

| Package | Test file |
|---|---|
| offlinelab-base | `tests/test_base.py` |
| offlinelab-testing | `tests/test_testing.py` |
| offlinelab-bootconf | `tests/test_bootconf.py` |
| offlinelab-disco | `tests/test_disco.py` |
| offlinelab-firewall | `tests/test_firewall.py` |
| offlinelab-framework | `tests/test_base.py` (framework section) |
| offlinelab-portable | `tests/test_portable.py` |
| offlinelab-resources | `tests/test_resources.py` |
| offlinelab-ssh | `tests/test_ssh.py` |
| offlinelab-update | `tests/test_rauc.py` |
| offlinelab-usb-gadget | `tests/test_usb_gadget.py` |
| offlinelab-wifi | `tests/test_wifi.py` |
| offlinelab-zram | `tests/test_zram.py` |
| rootfs_overlay / skeleton | `tests/test_system.py` |
| boot health / mounts | `tests/test_boot.py` |

---

## Framework

Bash utility library (`framework/library/`) and device management CLI (`framework/bin/boxctl*`).
Installed to `/usr/lib/framework/` on the target device.

See [docs/framework/index.md](docs/framework/index.md) for the full module reference.

### Quick reference

```bash
source framework/bin/dev-setup   # set FRAMEWORK_LIB_PATH for local dev
bin/test-framework --lint        # lint + full test suite (run before claiming done)
bin/test-framework --filter var  # run a single module's tests
shellcheck -s bash framework/library/*.sh framework/bin/boxctl*
```

### Function conventions — non-negotiable

```bash
function namespace::function_name() {
    log::trace "${FUNCNAME[0]}: One-line description"
    [[ "${#}" -ne 1 ]] && return 2
    local value="${1}"
    shift
    # implementation
}
```

Rules: `namespace::name` — lowercase, underscores, `::` separator. First line is always `log::trace`. Return 0/1/2. Validate arg count before touching `$1`. Shift after capturing locals. No `export -f`.

### Adding a new library module

1. Create `framework/library/<name>.sh` with the standard header (see CLAUDE.md for Bash instructions)
2. Add to `FRAMEWORK_INIT_MODULES` in `framework/library/import.sh`
3. Add tests at `framework/tests/unit/test_<name>.bats`
4. Run `bin/test-framework --lint`

---

## Docs

```bash
bin/generate-framework-docs   # regenerate framework API reference (docs/framework/)
uv run bin/docs.py            # build site to docs/public/
uv run bin/docs.py serve      # serve locally on :8000
```

Generated framework docs live in `docs/framework/` — do not edit them manually.
Nav defined in `zensical.toml`.
