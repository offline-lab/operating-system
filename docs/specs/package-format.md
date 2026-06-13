# Package Format

An Offline Lab package is a squashfs image of a single portable service, paired with
metadata and dm-verity companion files. buildctl produces it; appctl consumes it.

---

## File set

Every package consists of five files:

```
<name>-<version>-<arch>.squashfs              ← the service image (read-only filesystem)
<name>-<version>-<arch>.squashfs.roothash     ← dm-verity root hash (hex string)
<name>-<version>-<arch>.squashfs.roothash.p7s ← PKCS7 signature over the root hash
<name>-<version>-<arch>.squashfs.verity       ← dm-verity hash tree
<name>-<version>-<arch>.json                  ← package metadata
```

All five files must be present and co-located. systemd discovers the `.roothash`,
`.roothash.p7s`, and `.verity` companion files by name; they must have the squashfs
filename as their prefix.

**Transport:** for download or USB transfer, all five files are wrapped in a zip:

```
<name>-<version>-<arch>.zip
```

appctl extracts the zip once to the permanent images directory; the zip is not retained.
See [Security Model](security-model.md) for the trust chain and verification flow.

---

## Naming convention

| Field | Rules | Example |
|---|---|---|
| `name` | Lowercase, alphanumeric and hyphens only; must start with alphanumeric | `mosquitto` |
| `version` | Valid semver | `2.0.18` |
| `arch` | Enum: `arm64`, `armv7`, `armv6`, `amd64` | `arm64` |

Full example:
```
mosquitto-2.0.18-arm64.squashfs
mosquitto-2.0.18-arm64.squashfs.roothash
mosquitto-2.0.18-arm64.squashfs.roothash.p7s
mosquitto-2.0.18-arm64.squashfs.verity
mosquitto-2.0.18-arm64.json
```

---

## package.yaml

`package.yaml` is the build-time package definition. Package authors write it; buildctl
reads it to build the squashfs and generate the metadata JSON.

buildctl ships `package.yaml` inside the squashfs at `/usr/share/<name>/package.yaml`.
This provides build-time provenance without requiring access to the source repository.
The Dockerfile is not included. Publishing it is the maintainer's responsibility.

Fields not set in `package.yaml` fall back to Docker labels baked into the image, then
to defaults where applicable.

### Field reference

**Identity**

| Field | Type | Required | Notes |
|---|---|---|---|
| `spec_version` | string | yes | Always `"1"` |
| `name` | string | yes | Lowercase, alphanumeric + hyphens |
| `version` | string | yes | Semver |
| `arch` | string | yes | See naming convention above |
| `description` | string | yes | Single line |
| `homepage` | string | no | URL |
| `license` | string | no | SPDX identifier (e.g. `Apache-2.0`) |
| `tags` | string[] | no | Used for repo search and filtering |

**Publisher and contact**

| Field | Type | Required | Notes |
|---|---|---|---|
| `publisher` | string | yes | Publisher organisation (e.g. `offline-lab`) |
| `publisher_url` | string | no | Publisher homepage URL |
| `maintainer` | string | no | Package maintainer, format `"Name <email>"` |
| `source_url` | string | no | Source repository URL |
| `security_contact` | string | no | Email or URL for vulnerability reports |
| `sbom_url` | string | no | URL to a published SBOM for this package |

**Runtime**

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `systemd_profile` | string | no | `strict` | `default`, `strict`, `trusted`, `nonetwork`, `custom` |
| `socket_activation` | boolean | no | `false` | If true, a `.socket` unit must exist inside the squashfs |

`systemd_profile: "custom"` means the unit files inside the squashfs carry their own
security directives. The tooling attaches with `--profile=default` as a baseline. Full
security responsibility shifts to the app author. Custom-profile packages are flagged
in `appctl list` output and in the repo index.

**Volumes**

| Field | Type | Required | Notes |
|---|---|---|---|
| `volumes.config` | string | no | Namespace path for the config volume (e.g. `/etc/mosquitto`) |
| `volumes.data` | string | no | Namespace path for the data volume (e.g. `/var/lib/mosquitto`) |

Exactly two keys: `config` and `data`. No freeform paths. appctl generates `BindPaths=`
from these at install time. See [User Allocation](user-allocation.md) for the system
path layout and drop-in format.

Apps log via stderr/stdout to the systemd journal. No log volume is provided.

**Ports** (array, may be empty)

| Field | Type | Required | Notes |
|---|---|---|---|
| `port` | integer | yes | 1–65535 |
| `protocol` | string | yes | `tcp` or `udp` |
| `description` | string | no | |
| `expose` | boolean | yes | If true, an nftables accept rule is applied on install |

**Devices** (array, may be empty)

| Field | Type | Required | Notes |
|---|---|---|---|
| `type` | string | yes | `audio`, `video`, `bluetooth`, `gpio`, `i2c`, `spi`, `serial`, `usb` |
| `required` | boolean | yes | If false, service starts even if device is absent |
| `description` | string | no | |

**Resources** (optional)

Declares expected resource usage at three load levels. Used by appctl for pre-install
capacity checks. See [Resource Tracking](resource-tracking.md).

```yaml
resources:
  low:
    cpu_percent: 2
    memory_mb: 24
    storage_mb: 45
  moderate:
    cpu_percent: 15
    memory_mb: 64
    storage_mb: 45
  heavy:
    cpu_percent: 40
    memory_mb: 128
    storage_mb: 45
```

If omitted, appctl skips the resource check and proceeds with a warning.

**Lifecycle** (optional)

Each value is a systemd unit name that must exist inside the squashfs. Omit any hook
the app does not need. Omit the entire `lifecycle:` block if the app has no hooks.
See [Lifecycle Hooks](lifecycle.md) for sequencing and execution context.

| Field | When appctl starts it |
|---|---|
| `pre_start` | After portablectl attach, before enable and first start |
| `post_start` | After the service is running for the first time |
| `pre_update` | After new image is attached, before service restart |
| `post_update` | After the service is running on the new image |
| `pre_remove` | Before the service is stopped and the image is detached |

**Build options**

| Field | Type | Notes |
|---|---|---|
| `strip.enabled` | boolean | Remove unused shared libraries after build. Default false. |
| `strip.keep` | string[] | Library paths to preserve during stripping (e.g. dlopen'd libs). |

`strip` is build-time only; it does not appear in the generated metadata JSON.

### Full example

```yaml
spec_version: "1"

name: mosquitto
version: 2.0.18
arch: arm64
description: Lightweight MQTT broker
homepage: https://mosquitto.org
license: EPL-2.0
tags: [networking, mqtt, iot]

publisher: offline-lab
publisher_url: https://offline-lab.com
maintainer: "Flip Hess <flip@fliphess.com>"
source_url: https://github.com/offline-lab/apps
security_contact: security@offline-lab.com
sbom_url: ~

systemd_profile: strict
socket_activation: false

volumes:
  config: /etc/mosquitto
  data:   /var/lib/mosquitto

ports:
  - port: 1883
    protocol: tcp
    description: MQTT
    expose: true

devices: []

resources:
  low:      { cpu_percent: 2,  memory_mb: 24,  storage_mb: 45 }
  moderate: { cpu_percent: 15, memory_mb: 64,  storage_mb: 45 }
  heavy:    { cpu_percent: 40, memory_mb: 128, storage_mb: 45 }

# lifecycle: omitted (mosquitto uses ExecStartPre= in its unit file for first-run init)
```

---

## Metadata JSON

The metadata JSON is generated by buildctl from `package.yaml` and is **immutable after
publication**. It is the source of truth for appctl at install time. It does not
duplicate information that lives inside the squashfs (unit file directives, internal
capabilities); only fields the tooling needs to act on.

The metadata JSON does not include `uid` or `gid`. User allocation is appctl's
responsibility at install time, not the package author's. See
[User Allocation](user-allocation.md).

### Field reference

All fields from `package.yaml` carry over to the metadata JSON, except `strip` (build
input only). The following fields are added by buildctl at build time:

| Field | Type | Notes |
|---|---|---|
| `squashfs_size` | integer | Size of the squashfs in bytes. Used for pre-flight storage checks. |
| `created_at` | string | ISO 8601 build timestamp. |

The following field is reserved null in v1:

| Field | Notes |
|---|---|
| `signing_key_id` | Reserved. Will identify which signing key was used; required for key rotation support. See [Security Model](security-model.md). |

`signature` (embedded JSON signature) has been dropped. Signing is via the
`.roothash.p7s` companion file only.

### Full example

```json
{
  "spec_version": "1",

  "name": "mosquitto",
  "version": "2.0.18",
  "arch": "arm64",
  "description": "Lightweight MQTT broker",
  "homepage": "https://mosquitto.org",
  "license": "EPL-2.0",
  "tags": ["networking", "mqtt", "iot"],

  "publisher": "offline-lab",
  "publisher_url": "https://offline-lab.com",
  "maintainer": "Flip Hess <flip@fliphess.com>",
  "source_url": "https://github.com/offline-lab/apps",
  "security_contact": "security@offline-lab.com",
  "sbom_url": null,

  "signing_key_id": null,

  "squashfs_size": 4194304,
  "created_at": "2026-01-15T10:00:00Z",

  "systemd_profile": "strict",
  "socket_activation": false,

  "volumes": {
    "config": "/etc/mosquitto",
    "data": "/var/lib/mosquitto"
  },

  "ports": [
    {
      "port": 1883,
      "protocol": "tcp",
      "description": "MQTT",
      "expose": true
    }
  ],

  "devices": [],

  "resources": {
    "low":      { "cpu_percent": 2,  "memory_mb": 24,  "storage_mb": 45 },
    "moderate": { "cpu_percent": 15, "memory_mb": 64,  "storage_mb": 45 },
    "heavy":    { "cpu_percent": 40, "memory_mb": 128, "storage_mb": 45 }
  }
}
```
