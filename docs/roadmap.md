# Roadmap

Development is organised in phases. Each builds on the previous one.

| Phase | Status | Summary |
|---|---|---|
| 0 — Base OS | Complete | Minimal read-only OS for Pi Zero 2W |
| 1 — A/B updates | In progress | Atomic updates via U-Boot and RAUC |
| 2 — Discovery | Complete | Service discovery and name resolution |
| 3 — Portable services | Complete | systemd portable services and security hardening |
| 4 — App packaging | Planned | .olab format, pkgctl, appctl, build pipeline |
| 5 — Package repository | Planned | Index, distribution, publishing |
| 6 — Packages | Planned | First real portable service packages |
| 7 — Disco enhancements | Planned | Service aliases, announce hooks |

## Phase 0: Base OS

**Status: Complete**

A minimal read-only Linux image for the Raspberry Pi Zero 2W. The OS boots from SD card with a Buildroot-built arm64 kernel, connects to WiFi using credentials provisioned from the boot partition, and provides SSH and USB console access. An overlayfs layer keeps the rootfs immutable while allowing runtime state, and a dedicated data partition is auto-expanded on first boot.

## Phase 1: A/B updates

**Status: In progress**

Reliable A/B rootfs switching via U-Boot and RAUC, enabling atomic updates with automatic fallback on failure.

### Completed

Custom kernel defconfig, full U-Boot A/B bootchooser with per-slot counters and automatic fallback, new partition layout (boot + kernel/rootfs A + kernel/rootfs B + bootstate + overlay + data), per-slot overlay directories, and RAUC PKI with CA and signing keypair.

### Remaining

- `offlinelab-update` package: RAUC config, keyring, `rauc-mark-good.service`
- RAUC bundle generation in post-image.sh
- psplash boot splash
- USB update workflow (separate repo)

## Phase 2: Discovery

**Status: Complete**

Service discovery and name resolution for offline networks, implemented in [disco](disco.md). Devices find each other via UDP broadcast, hostnames resolve natively through a glibc NSS module, and an optional DNS server handles `.disco` domain queries. Includes time synchronisation from GPS sources.

## Phase 3: Portable services

**Status: Complete**

systemd portable service infrastructure with security hardening. Apps run as isolated portable services backed by `dm-verity` for image integrity and AppArmor for mandatory access control. The default portable profile enforces strict filesystem protection, memory limits (128 MB), and CPU quotas. An `admin` user has controlled sudo access for service management.

## Phase 4: App packaging foundation

**Status: Planned**

Defines the `.olab` package format, the tooling to build and run apps, and the app configuration model. This phase unblocks parallel work on services and tooling.

### Goals
- **`.olab` format spec** — single-file archive: squashfs + `metadata.json` + dm-verity
  roothash + signature. Metadata fields: name, version, arch, description, source-repo,
  tags, exposed-ports, required-data-dirs, min-os-version, file-listing, hashes.
  Spec published in [docs/app-format.md](app-format.md).
- **Config model** — bind-mount `/data/apps/<name>/config` → `/etc/<name>` inside the
  service. App images ship a skeleton generator; the install tool runs it on first
  attach if no config exists.
- **Isolation** — AppArmor + portabled isolation enforce per-app data boundaries.
  Apps cannot read each other's `/data/apps/<name>/` directories.
- **Portable service profiles** — base profile (always applied) + specialised profiles
  (`webservice`, `audio`, `network`). Defaults live in `offlinelab-portable`; apps may
  ship their own. Profile docs published on website with source links.
- **CLI split** — three distinct binaries, clearly documented:
  - `boxctl` — OS management (status, update, reboot, net, logs, diagnose)
  - `pkgctl` — package index management (list, search, info, publish)
  - `appctl` — app lifecycle (install, start, stop, restart, enable, disable, remove, list)
- **Build pipeline** — Docker (`FROM scratch` final stage) → `mksquashfs` → dm-verity
  seal → sign → produce `.olab`. `mkosi` also supported as build tool.
- **Reference app** — `lighttpd` serving a single `index.html`: validates the full
  build → package → install → start → disco-announce pipeline.

### Open questions to resolve during phase
- Finalise the YAML DSL for `appctl` multi-app definitions (compose-like)

## Phase 5: Package repository

**Status: Planned**

Index, distribution, and publication of `.olab` packages.

### Goals
- **Index format** — signed JSON manifest per arch. Fields: name, version, arch, size,
  hashes (sha256 of `.olab`), source-repo, tags, last-updated. Directory layout:
  `packages/<a>/<b>/<c>/<name>/<name>-<version>-<arch>.olab`.
- **Arch separation** — one repo tree per architecture (arm64, armv7, …). A client
  is configured for its arch and pulls only relevant packages.
- **Repo server** — minimal HTTP server (on-device via `appctl serve` and in
  packaging tools on the host). Serves index + packages from any directory, SDcard,
  USB drive, or remote URL.
- **Publishing workflow** — PR-based on the official packages repo; CI builds and
  publishes on merge. Third-party repos follow the same index format — anyone can
  host.
- **`pkgctl` subcommands** — `list`, `search`, `info`, `add-source`, `mirror`,
  `publish`.

## Phase 6: Services

**Status: Planned**

First real portable services, built on the Phase 4/5 toolchain. Release criteria:
at least 3–4 apps working and a clear template for adding more.

### Priority order
1. `lighttpd` mini-webservice + shared vhost model (reference, packaging template)
2. Audio player with Bluetooth and HDMI output
3. Book manager / e-reader with Kobo sync
4. Notes app
5. p2000 / SDR monitor
6. ROM manager + retro gaming
7. Video player (heavier, requires more RAM management)
8. Community apps (recipe manager, social, education) — interest-driven

Each service is a separate repository under `offline-lab/`. Open-source projects
packaged as portable services; custom builds or slimmed forks where resource
constraints require it.

## Phase 7: Disco enhancements

**Status: Planned** — work happens in [github.com/offline-lab/disco](https://github.com/offline-lab/disco)

- **Service aliases** — publish virtual hostnames per node so multiple vhost-based
  services on one IP are independently discoverable (e.g., `wiki.local`,
  `map.local`). Check whether current ANNOUNCE protocol already supports this;
  extend if not.
- **Disco announce hook** — `ExecStartPost` in portable service units calls
  `disco announce` so the network learns about new services immediately on start.
  Cheaper than D-Bus polling.

## Future

Not yet assigned to a phase. Needs design before stories can be sized.

### Data service
Storage durability on unreliable SD/USB media, and secure peer-to-peer data
exchange. Data classification model (Domain, Public, Shared, Local, Private,
Encrypted) governs which data syncs to which peers and under what conditions.
Syncthing as likely sync backend, wrapped to respect classifications. Separate
indexing layer so individual data sets (e.g., OSM tiles, personal routes) can be
selectively shared or withheld. Needs a dedicated brainstorm before stories.

### HTTP management API
Mini Go service exposing app management over HTTP/RPC. Allows remote start/stop,
updates, and status queries without SSH. Auth model TBD (SSH-key-based or
lightweight token). Separate from `appctl` (single-device) — this is the
multi-device control plane.

### Multi-node scheduler
Run and coordinate apps across multiple nodes from a single control point.
Companion to the HTTP API.

### Multi-node connectivity
- WiFi credential exchange over Bluetooth (field provisioning + inter-network
  discovery)
- Direct USB node-to-node link for cross-network data sync
- Batman-adv mesh networking (exploratory)
- LoRa / Meshtastic integration (exploratory)

### Additional hardware
Support for Pi 4, Pi 5, and other arm64 SBCs. New board = new `boards/<name>/`
directory + defconfig. Shared `offlinelab-base` across all boards.
