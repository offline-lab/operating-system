# Repository

An Offline Lab repository is a static directory of files. Any HTTP server, USB drive,
or local filesystem path can serve as a repository. No dynamic API is required.

---

## Design principles

- **Static files only**: nginx, caddy, a Python `http.server`, or a USB drive all work
  without modification. No server-side logic.
- **Same format everywhere**: the same index works over HTTP, HTTPS, and `file://`.
  Relative URLs ensure indexes are portable across transports.
- **Per-arch indexes**: each architecture has its own index file. Devices download only
  the index for their arch. This bounds index size regardless of how many arches the
  repo supports.
- **Signed indexes**: each arch index is signed via `.p7s`. appctl verifies before
  trusting any package entry.
- **Latest version only**: each arch index carries one entry per package (the latest
  published version). Version history is a client-side concern; rollback uses locally
  retained images.

---

## Directory layout

```
/                                               ← repo root (served at base_url)
  index.json                                    ← discovery document (arches + keys)
  index.json.p7s                                ← signature over discovery document
  keys/
    signing-<key-id>.crt                        ← public signing cert(s); one per active key
  packages/
    arm64/
      index.json                                ← arm64 package index
      index.json.p7s                            ← signature over arm64 index
      mosquitto/
        2.0.18/
          mosquitto-2.0.18-arm64.zip            ← transport archive (all 5 files)
          mosquitto-2.0.18-arm64.json           ← package metadata
          mosquitto-2.0.18-arm64.squashfs
          mosquitto-2.0.18-arm64.squashfs.roothash
          mosquitto-2.0.18-arm64.squashfs.roothash.p7s
          mosquitto-2.0.18-arm64.squashfs.verity
    amd64/
      index.json
      index.json.p7s
      ...
```

Packages are nested under `<arch>/<name>/<version>/` to bound the number of files per
directory. Flat arch-level directories degrade on USB and SD card filesystems as a repo
grows. Files keep their full `<name>-<version>-<arch>.*` names for readability when
copying or backing up.

Individual package files are served alongside the zip for clients that want to fetch
only the metadata or verify files directly.

---

## Root index.json (discovery document)

The root `index.json` is a lightweight discovery document. appctl fetches it at
`repo add` time to find the arch-specific index URL and the repo's signing keys.
It does not contain package entries.

### Field reference

| Field | Type | Required | Notes |
|---|---|---|---|
| `spec_version` | string | yes | Always `"1"` |
| `name` | string | yes | Human-readable repo name |
| `updated_at` | string | yes | ISO 8601 timestamp |
| `keys` | array | yes | All currently valid signing certs. See below. |
| `arches` | array | yes | Available arch-specific indexes. |

**keys entries**

| Field | Type | Required | Notes |
|---|---|---|---|
| `key_id` | string | yes | Cert fingerprint (SHA-256 of DER, hex) |
| `type` | string | yes | `"build"` or `"index"`. See below. |
| `cert_url` | string | yes | Relative URL to the cert file in `keys/` |
| `active` | boolean | yes | True if this key is currently used to sign new packages or indexes |
| `expires_at` | string | no | ISO 8601. appctl removes this cert once all packages signed by it have been updated and this date has passed. |

**Key types:**
- `"build"`: signs `.roothash.p7s` for each package. Lives on the build machine; never
  copied to the repo server. appctl uses it to verify packages at install time.
- `"index"`: signs `index.json.p7s` for each arch index after each publish. Lives on the
  repo host. A compromised index key cannot forge package content; appctl always
  re-verifies the build-key signature on the package itself at install time.

At least one `"build"` key and one `"index"` key must have `active: true`. During key
rotation, both the old cert (`active: false`, `expires_at`) and the new cert
(`active: true`) are listed. Each key type is rotated independently.

**arches entries**

| Field | Type | Required | Notes |
|---|---|---|---|
| `arch` | string | yes | Architecture identifier |
| `index_url` | string | yes | Relative URL to the arch-specific index file |

### Full example

```json
{
  "spec_version": "1",
  "name": "Offline Lab Packages",
  "updated_at": "2026-01-15T10:00:00Z",

  "keys": [
    {
      "key_id": "a1b2c3d4e5f6",
      "type": "build",
      "cert_url": "keys/signing-a1b2c3d4e5f6.crt",
      "active": true,
      "expires_at": null
    },
    {
      "key_id": "f6e5d4c3b2a1",
      "type": "index",
      "cert_url": "keys/signing-f6e5d4c3b2a1.crt",
      "active": true,
      "expires_at": null
    }
  ],

  "arches": [
    { "arch": "arm64", "index_url": "packages/arm64/index.json" },
    { "arch": "amd64", "index_url": "packages/amd64/index.json" }
  ]
}
```

---

## Per-arch index.json

Each arch has its own `packages/<arch>/index.json` containing only the packages for
that arch. Devices download only the index for their own arch, regardless of how many
arches the repo supports.

### Field reference

| Field | Type | Required | Notes |
|---|---|---|---|
| `spec_version` | string | yes | Always `"1"` |
| `arch` | string | yes | Architecture this index covers |
| `updated_at` | string | yes | ISO 8601 timestamp of last update |
| `key_rotation` | integer | no | Incremented on each key rotation. Default 0. |
| `packages` | array | yes | One entry per package (latest version). |

**packages entries**

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | Package name |
| `version` | string | yes | Semver |
| `description` | string | yes | Single-line description |
| `tags` | string[] | no | Used for search and filtering |
| `squashfs_size` | integer | yes | Bytes; used for pre-install storage check |
| `signing_key_id` | string | yes | `key_id` of the cert used to sign this package's `.roothash.p7s` |
| `custom_profile` | boolean | no | True if `systemd_profile: custom`. Default false. |
| `metadata_url` | string | yes | Relative path to the `.json` metadata file |
| `zip_url` | string | yes | Relative path to the `.zip` transport archive |

`custom_profile: true` is flagged in `appctl list` output. It means the package uses
`systemd_profile: custom` and carries its own security directives rather than the
standard profiles.

Relative paths in `metadata_url` and `zip_url` are relative to the repo `base_url`,
not to the arch index file itself.

### Full example

```json
{
  "spec_version": "1",
  "arch": "arm64",
  "updated_at": "2026-01-15T10:00:00Z",
  "key_rotation": 0,

  "packages": [
    {
      "name": "mosquitto",
      "version": "2.0.18",
      "description": "Lightweight MQTT broker",
      "tags": ["networking", "mqtt", "iot"],
      "squashfs_size": 4194304,
      "signing_key_id": "a1b2c3d4e5f6",
      "custom_profile": false,
      "metadata_url": "packages/arm64/mosquitto/2.0.18/mosquitto-2.0.18-arm64.json",
      "zip_url": "packages/arm64/mosquitto/2.0.18/mosquitto-2.0.18-arm64.zip"
    }
  ]
}
```

---

## Index signatures

Both the root `index.json` and each per-arch `index.json` are signed with a companion
`.p7s` file generated by `buildctl index sign`. This command runs on the **repo host**
using the repo's **index key**, not the build key.

appctl verifies the arch index signature at every `repo refresh` before trusting any
package entry. The root index signature is verified at `repo add` time.

Verification uses the stored index cert (type `"index"` in the keys array):
```
openssl cms -verify -CAfile /data/config/keys/<repo-hash>-<index-key-id>.crt \
    -in packages/arm64/index.json.p7s -content packages/arm64/index.json
```

Package content is verified separately at install time against the build cert
(type `"build"`). The two verification paths are independent.

An unsigned or unverifiable index is rejected. There is no `--force`, `--skip-verify`,
or equivalent flag to bypass signature verification. A flag to skip it would make the
entire signing model optional and therefore meaningless.

---

## Client flow

### appctl repo add \<url\> --name \<alias\>

1. Fetch `<url>/index.json` and `<url>/index.json.p7s`
2. Find all `active: true` entries in `keys[]`; fetch each cert from `<url>/<cert_url>`
3. Find the active `"index"` cert; verify `index.json.p7s` against it
4. Store all fetched certs at `/data/config/keys/<repo-hash>-<key-id>.crt`
5. Determine device arch; fetch `<url>/<index_url>` and its `.p7s`
6. Verify arch index `.p7s` against the stored index cert
7. Write repo record to `packages.db`; cache package entries

`<url>` becomes the authoritative origin for this repo. All subsequent downloads must
resolve to the same origin. See Trust rules below.

### appctl repo refresh

1. Fetch fresh root `index.json` and `index.json.p7s`
2. Verify root index `.p7s` against the stored index cert
3. Check `keys[]` for new `key_id` values not yet stored locally; fetch and store them
4. Fetch fresh arch `packages/<arch>/index.json` and `.p7s`
5. Verify arch index `.p7s` against the stored index cert
6. If `key_rotation` counter has increased: mark all installed packages from this repo
   for re-verification on next reattach
7. Update the local package cache in `packages.db`

### appctl search \<term\>

Filters the cached package index by name, description, and tags. Sorted by name.
Custom-profile packages are flagged in output.

### appctl install \<name\>

1. Find the entry for `<name>` in the cached arch index
2. Check `squashfs_size` against available storage
3. Verify `zip_url` resolves to the same origin as `base_url` (same-server rule)
4. Download `zip_url` to a temp location
5. Extract: verify all five files are present and correctly named
6. Verify `.roothash.p7s` using the cert matching `signing_key_id`
7. Stage files to `/data/offline-lab/images/<uuid>/`
8. Continue with install flow (see [Lifecycle](lifecycle.md))

### appctl install \<name\>@\<version\>

Same as above. The index only carries the latest version; pinned installs of older
versions must use a `file://` repo pointing to the specific version directory.

---

## Key rotation

See [Security Model: Key Rotation](security-model.md#key-rotation) for the full flow.

In brief:
- **Option A (recommended):** generate a new key, sign new packages going forward,
  publish both old and new certs in the root `keys[]`. Devices pick up the new cert on
  next `repo refresh`. Old cert carries `expires_at`; installed packages transition at
  their own pace.
- **Option B (clean cut-over):** re-sign all packages, increment `key_rotation` in the
  arch index, `repo refresh` triggers re-verification of all installed packages.

---

## Trust rules

**Same-server rule:** appctl rejects any `zip_url` or `metadata_url` that resolves to
a different origin than the `base_url` set at `repo add` time.

**No cross-origin redirects:** HTTP redirects to a different origin are rejected.
Redirects within the same origin (e.g. HTTP to HTTPS on the same host) are permitted.

**Single trust anchor:** the `base_url` from `repo add` is the trust anchor. The `url`
field inside any index file is informational and does not override it.

**Allowed protocols:** HTTP, HTTPS, and `file://`. Content integrity comes from PKCS7
signatures regardless of transport. HTTP is safe for offline and LAN repos where HTTPS
is impractical. `file://` is required for USB and air-gapped use.

---

## Local index generation

`buildctl index generate <path>` scans a local package directory and produces valid
index files:

1. Walk `packages/<arch>/<name>/<version>/` for `.json` metadata files
2. For each arch: build a package list keeping only the latest version per package name
3. Write `packages/<arch>/index.json` for each arch found
4. Sign each arch index: `buildctl index sign packages/<arch>/index.json --key <key.pem>`
5. Write and sign the root `index.json` (discovery document)

**Incremental update:** `buildctl publish <package-dir> --repo <url>` adds or updates
a single package without requiring all packages locally:

1. Download the current arch index from the repo
2. Add or replace the entry for this package
3. Sign the updated index
4. Upload the package files and the new index to the repo

This is the normal publish workflow. Full regeneration from scratch is only needed when
bootstrapping a new repo or after option B key rotation.

---

## Repo status

Each repo in `packages.db` carries a `status` field:

| Status | Behaviour |
|---|---|
| `active` | Normal; refresh, install, update all permitted |
| `paused` | No automatic refresh or updates; manual install still works |
| `blocked` | All operations rejected; already-installed packages continue to run |

`appctl repo pause <name>` and `appctl repo block <name>` set this field.
