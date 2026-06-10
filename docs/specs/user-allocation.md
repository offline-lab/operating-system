# Per-App User Allocation and Storage Layout

Every installed app runs as a dedicated system user. No two apps share a uid or gid.
appctl owns all allocation; no users are pre-created in the base image.

---

## Identity scheme

Three distinct identifiers per app, each serving a different purpose:

| Identifier | Format | Example | Purpose |
|---|---|---|---|
| Repo hash | `sha1(url.lower())[:8]` | `a0d7b954` | Storage path prefix, collision-resistant |
| Username | `app<uid>` | `app6000` | Linux user account, always valid, always short |
| Display name | `<repo-alias>/<name>` | `offline-lab/mosquitto` | Human-readable, `appctl list` output |

**Repo hash** is derived from the canonical repo URL at `appctl repo add` time:
`sha1("https://packages.offline-lab.com".lower())[:8]` → `a0d7b954`. It is
immutable and cannot be manipulated: `/a/b/repo` and `/ab/repo` hash to different
8-char prefixes. Same approach as Home Assistant Supervisor.

**Username** is `app` followed by the decimal uid. Always starts with a letter,
always alphanumeric, always ≤ 9 chars. Works on busybox and all Linux systems.
The GECOS field carries the human-readable identity (`offline-lab/mosquitto`).

**Display name** uses the user-set repo alias (set at `appctl repo add --name <alias>`)
for readability. The alias is display-only — the repo hash is the canonical identifier.

---

## Storage layout

```
/data/apps/<repo-hash>/<name>/
  config/    ← app configuration (persistent, writable by app uid)
  data/      ← app runtime data  (persistent, writable by app uid)
```

Example:
```
/data/apps/a0d7b954/mosquitto/config/
/data/apps/a0d7b954/mosquitto/data/
```

Two apps named `mosquitto` from different repos are fully isolated:
```
/data/apps/a0d7b954/mosquitto/   ← offline-lab repo
/data/apps/f2c91e3a/mosquitto/   ← community repo, separate hash, separate uid
```

---

## File permissions inside the squashfs

The squashfs is read-only (dm-verity enforced). Ownership inside it only affects
whether the service process can read or execute files — not write them.

**Decision: all files inside the squashfs are owned by root (uid 0).**

- Binaries: `root:root 755` — world-executable
- Static files and config templates: `root:root 644` — world-readable
- No files inside the squashfs need to be owned by the service user

The service user (`app6000`) can read and execute these files via world permissions,
exactly as any user can execute `/usr/bin/mosquitto` on a normal Linux system.

**Why not use the app uid inside the squashfs:**
The uid is allocated at install time and is not known at build time. There is no
mechanism to specify it in the image. Attempting to use a placeholder uid and remap
at runtime (via `UIDMap=`) adds complexity and requires user namespace kernel support,
with no practical benefit for a read-only filesystem.

**Packaging constraints (must be documented in app-filesystem.md):**

1. Unit files inside the squashfs must not include `User=` or `Group=` directives.
   appctl generates these in a drop-in at install time. If present in the unit file,
   they are overridden by the drop-in, but their presence is misleading and buildctl
   should warn.

2. Services must not perform internal privilege dropping (calling `setuid()` or
   `setgid()` to a named user defined in the squashfs's own `/etc/passwd`). The
   service must run as the single user systemd assigns via `User=`. Upstream daemons
   that drop privileges internally must have this disabled in the Dockerfile/package
   (typically via a `--no-drop-privs` flag or equivalent).

3. Any file that needs to be writable at runtime must be in the bind-mounted
   `/data/apps/<hash>/<name>/` tree, not inside the squashfs.

---

## Writable storage: volumes

Package authors declare only the namespace target paths for each data category.
Exactly two fixed keys: `config` and `data`. No freeform paths. appctl controls
the system path entirely — a package cannot reference arbitrary system locations.

`package.yaml`:
```yaml
volumes:
  config: /etc/mosquitto     # system: .../config/ → /etc/mosquitto in namespace
  data:   /var/lib/mosquitto # system: .../data/   → /var/lib/mosquitto in namespace
```

The paths on the right are conventional Linux paths — exactly what the upstream daemon
expects. The package author knows these at build time and writes config files referencing
them normally. The system paths (containing the repo hash) are entirely managed by appctl
and invisible to the package author.

appctl-generated drop-in:
```ini
# /etc/systemd/system.attached/mosquitto.service.d/99-appctl.conf
[Service]
User=app6000
Group=app6000
BindPaths=/data/apps/a0d7b954/mosquitto/config:/etc/mosquitto
BindPaths=/data/apps/a0d7b954/mosquitto/data:/var/lib/mosquitto
```

**Default config seeding:** on first install, if a volume target path exists inside
the squashfs (e.g., `/etc/mosquitto/mosquitto.conf`), appctl copies its contents to
the writable system directory before the bind mount takes effect. This seeds the writable
config from the image's defaults. Subsequent installs (updates) do not overwrite
the user's live config — that is the `post_update` lifecycle hook's responsibility.

---

## Database schema

appctl never deletes app rows — they are marked `removed` to preserve uid assignments
permanently and enable reinstall to reuse the original uid.

```sql
CREATE TABLE repos (
    hash     TEXT PRIMARY KEY,   -- sha1(url.lower())[:8]
    url      TEXT UNIQUE NOT NULL,
    alias    TEXT UNIQUE NOT NULL,
    key_path TEXT NOT NULL        -- /data/config/keys/<hash>.crt
);

CREATE TABLE packages (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    repo     TEXT NOT NULL REFERENCES repos(hash),
    name     TEXT NOT NULL,
    uid      INTEGER UNIQUE NOT NULL,
    version  TEXT NOT NULL,
    status   TEXT NOT NULL DEFAULT 'installed',  -- 'installed' | 'removed'
    UNIQUE (repo, name)
);
```

---

## Allocation algorithm

### Allocate (at install)

1. Check for an existing row with `(repo_hash, name)` in any status.

   - **Found:** reuse the existing uid. Update `status = 'installed'` and `version`.
   - **Not found:** allocate `MAX(uid) + 1`, starting at 6000.

2. Insert or update the row.

3. Write sysusers snippet and call `systemd-sysusers` on it immediately.

4. Create home dirs (`/data/apps/<hash>/<name>/{config,data}`), `chown app<uid>`.

5. Seed config from squashfs defaults if first install.

6. Generate appctl drop-in with `User=`, `Group=`, `BindPaths=`.

7. Call `portablectl attach`.

Uids are monotonically increasing and never reused across different apps. The `MAX(uid)`
high-water mark is preserved even after rows are marked `removed`, preventing a newly
installed app from inheriting filesystem ownership from a previously purged app.

Reinstalling the same app (same `repo_hash` + `name`) reuses the original uid. Data
dirs remain correctly owned and no `chown` is needed.

---

## Collision handling

`(repo_hash, name)` is the unique key. Two apps with the same name from different repos
are different apps with different uids and fully isolated storage.

Installing an already-`installed` app errors:
```
error: offline-lab/mosquitto is already installed (use --force to reinstall)
```

| Flag | uid | data |
|---|---|---|
| _(none, already installed)_ | error | unchanged |
| `--force` | reused | kept |
| `--force --purge` | reused | deleted and reseeded from image defaults |

---

## Uninstall and cleanup

**`appctl remove <app>`** — detaches service, removes sysusers snippet, marks row
`removed`. Data in `/data/apps/<hash>/<name>/` is kept intact. Uid reserved.

**`appctl remove --purge <app>`** — same, plus deletes `/data/apps/<hash>/<name>/`.
Row stays in DB as `removed`; uid is permanently retired from the high-water mark.

**`appctl cleanup`** — dry-run by default. Removes `removed`-status rows from DB
and any orphaned directories on disk. Requires `--yes`. Refuses if a lock file is
present. Uid slots for cleaned-up rows remain retired.

---

## Persistence across reboots

The `/etc` overlay resets on every boot. appctl writes a sysusers snippet to
`/data/config/sysusers.d/<hash>-<name>.conf` at install:

```
u app6000 6000 "offline-lab/mosquitto" /data/apps/a0d7b954/mosquitto /bin/false
g app6000 6000 -
```

`offlinelab-sysusers.service` (runs before `sysinit.target`) calls:
```
systemd-sysusers /data/config/sysusers.d/*.conf
```

On remove the snippet is deleted; the user is not recreated on next boot.

---

## Buildroot implications

- `systemd-sysusers`: part of `BR2_PACKAGE_SYSTEMD`, already required
- `offlinelab-sysusers.service`: ships with `offlinelab-base` package
- No `useradd`/`groupadd` required
