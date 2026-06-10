-- offline-lab packages.db schema
-- Location on device: /data/offline-lab/packages.db
-- SQLite database. Source of truth for all installed package state.
--
-- Never rely on portablectl output or unit symlinks in /etc/systemd/system/ —
-- the overlayfs upper is ephemeral and is rebuilt from this database on slot switch
-- or boot via the app restore service.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS schema_version (
  version       INTEGER NOT NULL,
  applied_at    TEXT    NOT NULL    -- ISO 8601
);

INSERT INTO schema_version (version, applied_at)
VALUES (1, strftime('%Y-%m-%dT%H:%M:%SZ', 'now'));

-- One row per configured repository.
CREATE TABLE IF NOT EXISTS repos (
  url           TEXT PRIMARY KEY,
  name          TEXT,
  arch          TEXT NOT NULL,              -- device arch; which per-arch index to fetch
  status        TEXT NOT NULL DEFAULT 'active',
  last_fetched  TEXT,                       -- ISO 8601; NULL if never fetched

  CHECK (status IN ('active', 'paused', 'blocked'))
  -- Signing certs are stored as files at:
  --   /data/config/keys/<repo-hash>-<key-id>.crt
  -- Not tracked in this table; appctl resolves them by key_id at verify time.
);

-- Cached package entries from each repo's per-arch index.
-- Replaced in full on every successful repo refresh.
CREATE TABLE IF NOT EXISTS package_cache (
  repo_url        TEXT NOT NULL,
  name            TEXT NOT NULL,
  version         TEXT NOT NULL,
  description     TEXT,
  tags            TEXT,                     -- JSON array string
  squashfs_size   INTEGER,
  signing_key_id  TEXT,
  custom_profile  INTEGER NOT NULL DEFAULT 0,  -- 0=false, 1=true
  metadata_url    TEXT,
  zip_url         TEXT,

  PRIMARY KEY (repo_url, name),
  FOREIGN KEY (repo_url) REFERENCES repos (url) ON DELETE CASCADE
);

-- One row per retained image. Multiple rows per (name, arch) for rollback support.
-- Default retention: 3 images per app per arch. Enforced after each successful install.
CREATE TABLE IF NOT EXISTS images (
  uuid          TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  arch          TEXT NOT NULL,
  version       TEXT NOT NULL,
  status        TEXT NOT NULL,              -- active | previous | removed
  staged_at     TEXT NOT NULL,             -- ISO 8601
  squashfs_path TEXT NOT NULL,             -- /data/offline-lab/images/<uuid>/

  CHECK (status IN ('active', 'previous', 'removed'))
);

-- One row per installed app. Tracks the currently active install.
-- uid/gid are allocated by appctl at install time from the per-app UID range
-- (6000+). They never change for the life of the install.
-- See docs/specs/user-allocation.md.
CREATE TABLE IF NOT EXISTS packages (
  name          TEXT NOT NULL,
  arch          TEXT NOT NULL,
  version       TEXT NOT NULL,
  installed_at  TEXT NOT NULL,              -- ISO 8601
  updated_at    TEXT,                       -- ISO 8601; NULL if never updated
  source_repo   TEXT,                       -- repo URL; NULL for manual install
  active_uuid   TEXT NOT NULL,              -- UUID of the active image in images table
  uid           INTEGER,                    -- allocated at install time
  gid           INTEGER,                    -- allocated at install time
  metadata_json TEXT NOT NULL,              -- full metadata JSON snapshot from install

  PRIMARY KEY (name, arch),
  FOREIGN KEY (source_repo) REFERENCES repos (url) ON DELETE SET NULL,
  FOREIGN KEY (active_uuid) REFERENCES images (uuid)
);

CREATE INDEX IF NOT EXISTS idx_images_name_arch ON images (name, arch);
CREATE INDEX IF NOT EXISTS idx_images_status     ON images (status);
CREATE INDEX IF NOT EXISTS idx_packages_name     ON packages (name);
CREATE INDEX IF NOT EXISTS idx_cache_repo        ON package_cache (repo_url);
