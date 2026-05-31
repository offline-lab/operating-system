# Offline Lab OS — Build Repository

**Kanban boards:**
- Builder: [Project 3](https://github.com/orgs/offline-lab/projects/3) — config in `.claude/kanban.json`
- Framework: [Project 5](https://github.com/orgs/offline-lab/projects/5) — config in `framework/.claude/kanban.json`

See `AGENTS.md` for full agent instructions across all three areas.

---

## Monorepo layout

| Area | Path | What it is |
|---|---|---|
| Builder | `br2-external/`, `bin/`, `Dockerfile` | Buildroot external tree and build pipeline |
| Framework | `framework/` | Bash utility library and `labctl` CLI |
| Docs | `docs/`, `zensical.toml` | Zensical documentation site |

---

## Builder

Tasks tracked in [offline-lab/builder Project 3](https://github.com/orgs/offline-lab/projects/3).
Use `/kanban` to manage tasks.

**Completed:** Phase 0-2, Phase 3 (portable services + sysext/confext + dm-verity + AppArmor)
**Backlog:** [#25](https://github.com/offline-lab/builder/issues/25) (time sync, parked)

**Key constraints:**
- `framework/` is first-party source — edit it directly here, then rebuild the package
- No binaries or third-party source committed — everything fetched at build time
- No source copies from other repos — builder fetches via Buildroot SITE/git at build time; never paste source from framework, labctl, disco, or any other repo into `br2-external/`
- No tmpfs for state — use `/data` bind mounts
- SSH to buildbox: `SSH_AUTH_SOCK=/dev/null ssh -i .ssh/builder builder@buildbox`
- Never run `git commit`, `git push`, or `git amend` — user handles all git operations
- Run `<pkg>-dirclean` after editing `br2-external/` or `framework/` (buildroot cache)

---

## Framework

@~/.claude/instructions/bash.md

Bash utility library for the Offline Lab OS. Target: buildroot ARM Linux only.

**Quick reference:**
```bash
source framework/bin/dev-setup   # set FRAMEWORK_LIB_PATH for local dev
bin/test-framework --lint        # lint + full test suite (run before claiming done)
bin/test-framework --filter var  # run one module's tests
```

### Variable namespace

All internal variables use `FRAMEWORK_` prefix. Never `TOOLSET_`.

| Variable | Purpose |
|---|---|
| `FRAMEWORK_LIB_PATH` | Path to `framework/library/` |
| `FRAMEWORK_LIB_SOURCES` | Already-sourced files (circular import guard) |
| `FRAMEWORK_INIT_MODULES` | Modules auto-imported on load |
| `FRAMEWORK_BIN_PATH` | Path to `framework/bin/` |
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
| `sanity.sh` | Pre-execution sanity checks |
| `prettytable.sh` | Unicode table output |
| `cache.sh` | Key/value caching with TTL |
| `ssl.sh` | Certificate and key validation |
| `ssh.sh` | SSH key generation and agent management |
| `credentials.sh` | Username and password generation |
| `net.sh` | IP/FQDN validation (offline); `net::get_ip` (internet) |
| `system.sh` | `priv::run`, `system::sudo_keepalive` |
| `config.sh` | `/data/config` key/value store |
| `health.sh` | System health checks |
| `rauc.sh` | RAUC A/B OTA operations |
| `wifi.sh` | WiFi via wpa_cli |

### Runtime install layout

```
/usr/lib/framework/bin/framework   ← source this: source framework || exit 1
/usr/lib/framework/bin/labctl      ← device management CLI
/usr/lib/framework/bin/chronic     ← bash port of moreutils chronic(1)
/usr/lib/framework/*.sh            ← library modules
/etc/labctl/su.conf                ← labctl-su allowlist
/etc/profile.d/framework.sh       ← adds /usr/lib/framework/bin to PATH
```

### Dependency decisions

| Tool | Status | Notes |
|---|---|---|
| `awk`, `basename`, `dirname`, `realpath` | Required | busybox built-ins |
| `file` | Required | `core::is_sourceable` — `BR2_PACKAGE_FILE=y` |
| `jq` | Required | `BR2_PACKAGE_JQ=y` |
| `curl` | Required | `net.sh` — `BR2_PACKAGE_CURL=y` |
| `fzf` | Required | custom package at `br2-external/package/fzf/` |
| `openssl` | Under review | compute cost on ARM; `ssl.sh` may be dropped |
| `chronic` | Bash port done | `framework/bin/chronic` and `proc::chronic()` |
| `dig` | Removed | replaced by curl in `net::get_ip` |

Busybox compat: use `grep -E` not `-P`, `date -u` not `--universal`, `mktemp -t prefix-XXXX`.

### Architectural decisions — do not revert

- No `::init()` functions — deps declared at call site, not dynamically registered
- No runtime dep checking — we own the image; missing deps fail clearly
- No platform detection — Linux-only; macOS branches are dead code
- No `export -f` — scripts source the framework; exporting wastes memory
- `#!/usr/bin/env bash` shebang only — ensures `bash -x` always works
- `FRAMEWORK_` prefix everywhere — avoids collision with `~/.toolset`
- Privilege via `priv::run` / `sudo labctl-su` — never embed `sudo` inline

### Adding a new library module

1. Create `framework/library/<name>.sh` with header:
   ```bash
   #!/usr/bin/env bash
   # vi: ft=bash
   # shellcheck shell=bash disable=SC2312
   ```
2. Follow function conventions in `AGENTS.md`
3. Add to `FRAMEWORK_INIT_MODULES` in `framework/library/import.sh`
4. Add tests at `framework/tests/unit/test_<name>.bats`
5. Run `bin/test-framework --lint`

---

## Docs

```bash
bin/generate-framework-docs        # regenerate framework API reference
uv run bin/docs.py                 # build site to docs/public/
uv run bin/docs.py serve           # serve locally on :8000
```

Generated framework docs live in `docs/framework/` — do not edit them manually.
Nav defined in `zensical.toml`.
