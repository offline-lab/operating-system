# App format spec

!!! note "Work in progress"
    This spec is a work in progress. The fields and structure described here are subject to change.

## Overview

A `.olab` package is a single-file archive containing everything needed to install and run a portable service on MoreOS. It bundles a squashfs filesystem image, a metadata manifest, a dm-verity root hash, and a signature.

## File structure

```
<name>-<version>-<arch>.olab
├── rootfs.sqsh       # squashfs filesystem image
├── metadata.json     # package metadata
├── roothash          # dm-verity root hash
└── roothash.sig      # signature over the root hash
```

## Metadata fields

| Field | Type | Description |
|---|---|---|
| `name` | string | Package name, lowercase, hyphenated |
| `version` | string | Semantic version (`1.0.0`) |
| `arch` | string | Target architecture (`arm64`, `armv7`) |
| `description` | string | Short human-readable description |
| `source_repo` | string | URL of the upstream or packaging source repository |
| `tags` | list | Classification tags (e.g. `audio`, `network`, `webservice`) |
| `exposed_ports` | list | TCP/UDP ports the service listens on |
| `required_data_dirs` | list | Paths under `/data/apps/<name>/` the service expects |
| `min_os_version` | string | Minimum MoreOS version required |
| `file_listing` | list | List of files in the squashfs with sha256 hashes |

## Details to be finalised

- Exact signing mechanism and key distribution
- Config skeleton generator interface
- Portable service profile selection (`webservice`, `audio`, `network`)
- `mkosi` support alongside Docker builds

See the [roadmap](roadmap.md) for the full goals.
