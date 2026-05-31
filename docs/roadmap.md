# Roadmap

Development is organised in phases. Each builds on the previous one.

## Phase 0: Base OS

**Status: Complete**

Minimal read-only OS that boots on Pi Zero 2W, connects to WiFi, provides SSH and USB console access.

- Buildroot image for Raspberry Pi Zero 2W (arm64)
- Raspberry Pi foundation kernel (rpi-6.12.y), custom-trimmed defconfig
- Systemd init with systemd-networkd
- 4-primary-partition layout with overlayfs (lower=rootfs-a, upper on overlay partition)
- WiFi with credentials provisioned from boot partition
- SSH via dropbear, key-only auth, keys provisioned from boot partition
- USB composite gadget (serial ttyGS0 + ethernet usb0)
- GPIO UART console (ttyS0, 115200 baud)
- Data partition auto-expanded on first boot
- zram compressed swap
- Fake hardware clock for valid TLS before NTP

## Phase 1: A/B updates

**Status: In progress**

Reliable A/B rootfs switching via U-Boot and RAUC.

### Completed
- Custom kernel defconfig replacing the fragment-based approach
- U-Boot integration (single-slot, then full A/B bootchooser)
- New partition layout: boot + extended (kernel-a, rootfs-a, kernel-b, rootfs-b, bootstate) + overlay + data
- Per-slot overlay directories (`/overlay/a/`, `/overlay/b/`)
- U-Boot A/B bootchooser: BOOT_ORDER, per-slot counters, automatic fallback
- RAUC PKI (CA + signing keypair)

### Remaining
- `offlinelab-update` package: RAUC config, keyring, `rauc-mark-good.service`
- RAUC bundle generation in post-image.sh
- psplash boot splash
- USB update workflow (separate repo)

## Phase 2: Discovery

**Status: Complete**

Service discovery and name resolution for offline networks via [disco](disco.md).

- `disco-daemon`: UDP broadcast discovery (port 5354)
- `libnss_disco.so.2`: glibc NSS module for native hostname resolution
- `disco` CLI: host listing, lookup, service status
- Time synchronisation from GPS sources
- Optional DNS server for `.disco` domain
- `offlinelab-disco` Buildroot package

## Phase 3: Portable services

**Status: Complete**

Systemd portable service infrastructure and security hardening.

- `portabled` + `systemd-sysext` + `systemd-confext` enabled
- `offlinelab-portable` package: `/data/apps/`, `/data/extensions/`, `/data/confexts/` provisioned on first boot
- `dm-verity` with signed root hash verification
- AppArmor enabled (`LSM=apparmor`, `security=apparmor`)
- Default portable profile: `ProtectSystem=strict`, `NoNewPrivileges=yes`, `MemoryMax=128M`, `CPUQuota=50%`
- `admin` user with full sudo (portablectl, sysext, confext)
- Hello-world test service validated

## Phase 4: App packaging foundation

**Status: Planned**

Defines the `.olab` package format, the tooling to build and run apps, and the
app configuration model. This phase unblocks parallel work on services and tooling.

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
  - `labctl` — OS management (status, update, reboot, net, logs, diagnose)
  - `pkgctl` — package index management (list, search, info, publish) — rename from `olpfctl`
  - `appctl` — app lifecycle (install, start, stop, restart, enable, disable, remove, list)
- **Build pipeline** — Docker (`FROM scratch` final stage) → `mksquashfs` → dm-verity
  seal → sign → produce `.olab`. `mkosi` also supported as build tool.
- **Reference app** — `lighttpd` serving a single `index.html`: validates the full
  build → package → install → start → disco-announce pipeline.

### Open questions to resolve during phase
- Finalise the YAML DSL for `appctl` multi-app definitions (compose-like)
- Decide `pkgctl` rename (see [#TBD](https://github.com/offline-lab/builder/issues))

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
