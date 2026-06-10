# Offline Lab OS — Build Repository

**Kanban boards:**
- Builder: [Project 3](https://github.com/orgs/offline-lab/projects/3) — config in `.claude/kanban.json`
- Framework: [Project 5](https://github.com/orgs/offline-lab/projects/5) — config in `framework/.claude/kanban.json`

See `AGENTS.md` for agent instructions. See `docs/` for architecture, packages, and specs.

---

## Key constraints

- `framework/` is first-party source — edit it here, then rebuild the package
- No binaries or third-party source committed — everything fetched at build time
- No source copies from other repos — builder fetches via Buildroot SITE/git at build time
- No tmpfs for state — use `/data` bind mounts
- SSH to buildbox: `SSH_AUTH_SOCK=/dev/null ssh -i .ssh/builder builder@buildbox`
- Never run `git commit`, `git push`, or `git amend` — user handles all git operations
- Run `<pkg>-dirclean` after editing `br2-external/` or `framework/` (buildroot cache)

---

## Framework quick reference

```bash
source framework/bin/dev-setup   # set FRAMEWORK_LIB_PATH for local dev
bin/test-framework --lint        # lint + full test suite (run before claiming done)
bin/test-framework --filter var  # run one module's tests
```

All internal variables use `FRAMEWORK_` prefix. See [docs/framework/index.md](docs/framework/index.md) for the full module reference.
