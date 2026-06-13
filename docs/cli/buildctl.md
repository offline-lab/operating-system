# buildctl

buildctl is the developer-side CLI for building, signing, and publishing Offline Lab app packages. It runs on your workstation or CI machine — not on the device.

Source: [github.com/offline-lab/buildctl](https://github.com/offline-lab/buildctl) · Docs: [buildctl.offline-lab.com](https://buildctl.offline-lab.com)

## What it does

buildctl takes a service definition (Dockerfile or build script plus `package.yaml`) and produces a signed, verifiable package: a squashfs image with dm-verity companion files and metadata. See [Build spec](../specs/build.md) for the full pipeline.

## Planned subcommands

| Command | What it does |
|---|---|
| `build <dir>` | Build a squashfs image from `package.yaml` + backend source |
| `validate project <dir>` | Pre-build: check `package.yaml`, required files, field types |
| `validate image <dir>` | Post-build: verify five-file set, signatures, squashfs contents |
| `key generate` | Generate a build or index signing keypair |
| `publish <dir>` | Rsync package files to the repo host and update the index |
| `index generate <path>` | Scan a local package directory and produce index files |
| `index sign <file>` | Sign an index file with the index key |
| `index update` | Incremental single-package index update on the repo host |

## Build backends

buildctl supports multiple backends for producing the root filesystem:

| Backend | Use when |
|---|---|
| `docker` | You have a Dockerfile (default) |
| `shell` | You have a `build.sh` that produces a root filesystem |
| `make` | You have a Makefile target that produces a root filesystem |
| `mkosi` | systemd-native image build without a container runtime (planned) |

## Installation

buildctl is distributed as a Debian package:

```bash
apt install buildctl
```

It is a host-side development tool — it does not use the squashfs / portablectl app format and is not installed on devices.
