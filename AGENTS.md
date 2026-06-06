# AGENTS.md

Instructions for AI coding agents working in this repository.

---

## Monorepo Structure

This repository contains three distinct areas. Know which one you're working in
before making changes — conventions, tools, and constraints differ between them.

| Area | Path | What it is |
|---|---|---|
| **Builder** | `br2-external/`, `bin/`, `Dockerfile` | Buildroot external tree and build pipeline |
| **Framework** | `framework/` | Bash utility library and `boxctl` CLI for the OS |
| **Docs** | `docs/`, `zensical.toml` | Documentation site (Zensical static site) |

**Git:** Never run `git commit`, `git push`, or `git amend` — user handles all git operations.

---

## Builder

The build system for Offline Lab OS. Produces images for Raspberry Pi (Zero 2W, 3, 4) and QEMU arm64.

### Key commands

```bash
# Build inside Docker
bin/builder.sh build

# Build on native arm64 buildbox VM
bin/buildbox.sh build

# SSH to buildbox (never use SSH_AUTH_SOCK)
SSH_AUTH_SOCK=/dev/null ssh -i .ssh/builder builder@buildbox

# Sync code to buildbox
bin/buildbox.sh sync

# Rebuild a single package after editing source
make offlinelab-framework-dirclean && make offlinelab-framework
```

### Constraints

- No binaries or third-party source committed — everything fetched at build time
- No tmpfs for state — use `/data` bind mounts
- Run `<pkg>-dirclean` after editing `br2-external/` or `framework/` source files (buildroot cache)
- `framework/` is first-party source — edit it directly in this repo, then rebuild the package
- **File edits via Edit/Write tools only** — never use `sed -i`, `python`, or `awk` to rewrite working-tree files from Bash; Edit/Write produce visible diffs, Bash rewrites are opaque

### Structure

```
br2-external/
├── boards/common/           # shared board support (initramfs, fragments, splash)
├── boards/rpi/              # RPi family (hook, uboot, hardware kernel config)
│   ├── pi-zero-2w/          # Pi Zero 2W board (meta, firmware config, uboot fragment)
│   ├── rpi3/                # Raspberry Pi 3 board (meta)
│   └── rpi4/                # Raspberry Pi 4 board (meta)
├── boards/qemu/             # QEMU family (hook, uboot)
│   └── arm64/               # QEMU arm64 board (meta, hardware/uboot fragments)
├── configs/                 # buildroot defconfigs
├── package/                 # custom packages (offlinelab-base, -framework, -ssh, -wifi, etc.)
├── rootfs_overlay/          # static overlay files
├── skeleton/                # custom rootfs skeleton
├── devices.txt, users.txt   # device/user definitions
├── external.desc            # BR2_EXTERNAL descriptor
└── external.mk              # package/board includes

bin/                         # build pipeline scripts (Python + bash)
├── builder.sh               # Docker-based build environment
├── buildbox.sh              # native arm64 VM build pipeline
├── verify.sh                # automated image verification
├── docs.py                  # documentation site generator
├── generate-framework-docs  # framework API reference generator
├── test-framework           # framework test runner
└── ...
```

### Task tracking

Tasks tracked as GitHub issues in **offline-lab/builder**, managed via:
https://github.com/orgs/offline-lab/projects/3

Use `/kanban` to list, update, and create tasks. Config is in `.claude/kanban.json`.

---

## Framework

Bash utility library (`framework/library/`) and device management CLI (`framework/bin/boxctl*`).
Installed to `/usr/lib/framework/` on the target device.

See `framework/.claude/CLAUDE.md` for full context including variable namespace,
runtime install layout, and dependency decisions.

### Quick reference

```bash
# Dev setup (sets FRAMEWORK_LIB_PATH to framework/library/)
source framework/bin/dev-setup

# Run tests
bin/test-framework

# Run tests with lint
bin/test-framework --lint

# Run a single module's tests
bin/test-framework --filter var

# Lint only
shellcheck -s bash framework/library/*.sh framework/bin/boxctl*
shfmt -d -i 4 -ci framework/library/*.sh framework/bin/boxctl*
```

**Before claiming work is done:** `bin/test-framework --lint`

### Function conventions — non-negotiable

Every library function must follow this exact pattern:

```bash
function namespace::function_name() {
    log::trace "${FUNCNAME[0]}: One-line description of what it does"

    [[ "${#}" -ne 1 ]] && return 2  # validate arg count; return 2 on bad arity

    local value="${1}"
    shift

    # implementation
}
```

**Rules:**
1. Name: `namespace::function_name` — lowercase, underscores only, `::` separator
2. First line of body: `log::trace "${FUNCNAME[0]}: ..."` — always
3. Return codes: `0` success, `1` failure, `2` wrong argument count
4. Validate arg count before using positional args
5. `shift` after capturing named locals; never use bare `$1` after that
6. **No `export -f`** — every script sources the framework; exporting wastes memory

### Variable namespace

All framework-internal variables use the `FRAMEWORK_` prefix. Never `TOOLSET_`.

| Variable | Purpose |
|---|---|
| `FRAMEWORK_LIB_PATH` | Path to the `library/` directory |
| `FRAMEWORK_LIB_SOURCES` | Already-sourced files (circular import guard) |
| `FRAMEWORK_INIT_MODULES` | Modules auto-imported on load |
| `FRAMEWORK_BIN_PATH` | Path to `bin/` directory |
| `FRAMEWORK_SCRIPT_NAME` | Name of the calling script |

### Library modules

| Module | Purpose |
|---|---|
| `core.sh` | Bootstrap — source this first |
| `import.sh` | Module loader |
| `logging.sh` | Leveled logging: TRACE/DEBUG/INFO/WARN/ERROR |
| `exit.sh` | `exit::error`, `exit::info`, `exit::ok` |
| `debug.sh` | Stack trace trap |
| `var.sh` | Variable type/value checks |
| `array.sh` | Array operations |
| `string.sh` | String utilities |
| `fs.sh` | File and directory checks |
| `files.sh` | File merge and deduplication |
| `arguments.sh` | `--flag` CLI argument parsing |
| `interact.sh` | Yes/No confirmation prompts |
| `depends.sh` | Dependency checking |
| `proc.sh` | Process utilities (includes `proc::chronic`) |
| `time.sh` | Time formatting |
| `sanity.sh` | Pre-execution sanity check framework |
| `prettytable.sh` | Unicode table output |
| `cache.sh` | Key/value caching with TTL |
| `ssl.sh` | Certificate and key validation |
| `ssh.sh` | SSH key generation, agent management |
| `credentials.sh` | Username and password generation |
| `net.sh` | IP/FQDN validation (offline); `net::get_ip` (internet) |
| `system.sh` | `priv::run` (privilege wrapper), `system::sudo_keepalive` |
| `config.sh` | `/data/config` key/value store |
| `health.sh` | System health: failed units, AppArmor, verity, disk, memory |
| `rauc.sh` | RAUC A/B slot operations |
| `wifi.sh` | WiFi management via wpa_cli |

### Dependency discipline

Every external tool dependency costs buildroot build time. Justified dependencies:

| Tool | Status | Notes |
|---|---|---|
| `bash` | Required | `BR2_PACKAGE_BASH=y` |
| `awk`, `basename`, `dirname`, `realpath` | Required | busybox built-in |
| `file` | Required | `core::is_sourceable` — `BR2_PACKAGE_FILE=y` |
| `jq` | Required | `BR2_PACKAGE_JQ=y` |
| `curl` | Required | `net.sh` — `BR2_PACKAGE_CURL=y` |
| `fzf` | Required | custom package at `br2-external/package/fzf/` |
| `rauc` | Required | `BR2_PACKAGE_RAUC=y` |
| `wpa_supplicant` | Required | `BR2_PACKAGE_WPA_SUPPLICANT=y` |
| `iproute2` | Required | `BR2_PACKAGE_IPROUTE2=y` |
| `openssl` | Under review | compute cost on ARM; `ssl.sh` may be dropped |
| `chronic` | Bash port done | `framework/bin/chronic` and `proc::chronic()` |

Busybox compatibility rules:
- `grep -E` not `grep -P` (no PCRE in busybox grep)
- `date -u` not `date --universal`
- `mktemp -t prefix-XXXX` not `mktemp --suffix`
- No gawk-specific features

### Privilege escalation

Scripts use `sudo boxctl-su <cmd>` — never embed `sudo` inline. The `priv::run`
function in `system.sh` handles this: runs directly if already root, otherwise
delegates to `sudo boxctl-su`. Allowlist at `framework/etc/boxctl/su.conf`.

### Internet-requiring functions

```bash
# REQUIRES INTERNET
function net::example() {
    log::trace "${FUNCNAME[0]}: Fetches something"
    depends::check::silent curl || return 1
    curl -fsSL --max-time 5 ...
}
```

### Architectural decisions — do not revert

| Decision | Rationale |
|---|---|
| No `module::init()` | We control all deps; dynamic registration is overhead |
| No runtime dep checking | We own the image; missing deps fail clearly at the call site |
| No platform detection | Linux-only target; macOS branches are dead code |
| `FRAMEWORK_` prefix everywhere | Avoids collision with `~/.toolset` on dev machines |
| No `export -f` | Scripts source framework; exporting wastes memory |
| `dig` removed | `curl` used for `net::get_ip` instead |
| `#!/usr/bin/env bash` shebang only | Ensures `bash -x` debugging always works |

### Adding a new library module

1. Create `framework/library/<name>.sh` with the header:
   ```bash
   #!/usr/bin/env bash
   # vi: ft=bash
   # shellcheck shell=bash disable=SC2312
   ```
2. Follow function conventions above
3. Add module name to `FRAMEWORK_INIT_MODULES` in `framework/library/import.sh`
4. Add tests at `framework/tests/unit/test_<name>.bats`
5. Run `bin/test-framework --lint`

### Task tracking

Framework tasks tracked in **Project 5** (Command line utils and core):
https://github.com/orgs/offline-lab/projects/5

Config in `framework/.claude/kanban.json`.

---

## Docs

Documentation site using [Zensical](https://zensical.io) (Material Design static site).

### Key commands

```bash
# Generate framework API reference docs
python3 bin/generate-framework-docs

# Build the site
python3 bin/docs.py

# Serve locally
python3 bin/docs.py serve
# open http://localhost:8000
```

### Structure

```
docs/                       # source markdown files
├── index.md                # landing page
├── framework-index.md      # framework module overview (generated)
├── framework-*.md          # per-module API reference (generated)
├── framework-commands.md   # boxctl command reference (generated)
├── framework-integration.md # buildroot integration guide
└── ...                     # other OS docs

zensical.toml               # nav, theme, site metadata
bin/docs.py                 # site build and serve wrapper
bin/generate-framework-docs # extracts API docs from framework/library/*.sh
```

### Adding/editing docs

1. Create or edit a `.md` file in `docs/`
2. Add a nav entry to `zensical.toml` under the `nav` array
3. Run `python3 bin/docs.py` to rebuild
4. No frontmatter required — plain markdown

### Framework API docs

`docs/framework-*.md` files are auto-generated from source. Do not edit them manually —
edit the source in `framework/library/` and regenerate:

```bash
python3 bin/generate-framework-docs
```

The generator extracts:
- Module-level comments (top-of-file descriptions)
- Section headers (from `####...####` dividers)
- Per-function comment blocks (the `#\n# text\n#` pattern above each function)
- `log::trace` messages (function intent descriptions)
- Arity rules (from `[[ "${#}" -ne N ]]` checks)
