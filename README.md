# Offline Lab OS — br2-builder

Buildroot-based minimal OS for Raspberry Pi Zero 2W. A read-only mini os designed to
run systemd portable services from squashfs images. Built for offline, battery-powered use.

Part of the [offline-lab.com](https://offline-lab.com) project.

## Architecture

```
SD Card Layout (MBR with extended partition):
Primary:
  p1  boot       FAT32   32MB    firmware, U-Boot, initramfs, boot.scr
  p2  (extended)                 container for logical partitions
  p3  overlay    ext4    96MB    per-slot overlayfs upper+work dirs
  p4  data       ext4   64MB+   persistent storage (expanded on first boot)

Logical (inside p2):
  p5  kernel-a   sqfs   24MB    kernel Image (slot A)
  p6  rootfs-a   ext4  512MB    root filesystem (slot A)
  p7  kernel-b   sqfs   24MB    kernel Image (slot B)
  p8  rootfs-b   ext4  512MB    root filesystem (slot B)
  p9  bootstate  raw     8MB    U-Boot env (BOOT_ORDER, counters)
```

**Boot flow:**

1. RPi firmware (`bootcode.bin` → `start.elf`) loads U-Boot
2. U-Boot runs `boot.scr` — reads bootstate from p9, selects slot A or B
3. Loads kernel from slot's squashfs partition, initramfs from boot partition
4. Initramfs mounts rootfs read-only, per-slot overlayfs, data partition
5. `switch_root` to overlayfs — systemd starts, root appears writable

**Partition roles:**
- **boot** — U-Boot, boot.scr, initramfs, RPi firmware, DTBs, config files
- **kernel-a/b** — squashfs containing the kernel Image per slot
- **rootfs-a/b** — read-only root filesystem per slot (overlayfs lower)
- **bootstate** — raw U-Boot env: slot order, boot attempt counters, machine-id
- **overlay** — per-slot overlayfs upper/work dirs (`/overlay/a/`, `/overlay/b/`)
- **data** — persistent writable storage: home, config, portable services

## Repository layout

```
br2-builder/
├── bin/                          # all scripts and tooling
│   ├── builder.sh                # Docker-based build environment
│   ├── buildbox.sh               # native arm64 VM build pipeline
│   ├── build.sh                  # build script (runs inside Docker)
│   ├── build-image.sh            # per-board build script (runs on buildbox VM)
│   ├── run-qemu                  # run a QEMU arm64 image locally
│   ├── test-qemu-ota             # end-to-end RAUC OTA test in QEMU
│   ├── verify.sh                 # automated image verification
│   └── clean.sh                  # buildroot distclean
├── br2-external/                 # buildroot external tree
│   ├── boards/common/            # shared board support (initramfs, fragments, splash)
│   ├── boards/rpi/               # RPi family (hook, uboot, hardware kernel config)
│   │   ├── pi-zero-2w/           # Pi Zero 2W board (meta, firmware config, uboot fragment)
│   │   ├── rpi3/                 # Raspberry Pi 3
│   │   └── rpi4/                 # Raspberry Pi 4
│   ├── boards/qemu/              # QEMU family (hook, uboot)
│   │   └── arm64/                # QEMU arm64 board (meta, hardware/uboot fragments)
│   ├── configs/                  # buildroot defconfigs (one per board)
│   ├── package/offlinelab-*/     # OS packages
│   ├── rootfs_overlay/           # static overlay files
│   └── skeleton/                 # custom rootfs skeleton
├── docs/                         # project documentation
│   └── KERNEL.md                 # kernel strategy
├── Dockerfile                    # Docker build environment
├── config.example                # build-time config template
└── env.example                   # environment template
```

This repository contains only source code and configuration. No binaries, pre-built
images, or third-party source code is stored in git. Build artifacts go to `artifacts/`
(gitignored). External dependencies (disco, buildroot) are fetched at build time.

## Build

### Prerequisites

- Docker with `linux/arm64` platform support (Docker Desktop on macOS), or
- A native arm64 Debian host (physical or VM)
- ~15GB disk for build cache

### Quick start (Docker)

```bash
cp env.example .env
cp config.example .config
# Edit .env and .config with your settings

bin/builder.sh --build-docker
bin/builder.sh --build

# Or open a shell in the build container
bin/builder.sh --shell
# Then inside: bin/build.sh
```

### Native build (buildbox VM)

For faster builds without Docker emulation, use a native arm64 Debian VM:

```bash
# Create a new buildbox VM (Lima, cloud-init provisioned)
bin/buildbox.sh create

# Build all boards sequentially, fetch all artifacts (overnight run)
bin/buildbox.sh all

# Full pipeline for one board: sync, build, verify, fetch
bin/buildbox.sh                          # default: pi-zero-2w
bin/buildbox.sh qemu-arm64

# Or run steps individually
bin/buildbox.sh sync                     # push code to buildbox
bin/buildbox.sh build [board]            # sync + build (default: pi-zero-2w)
bin/buildbox.sh verify [board]           # run verification
bin/buildbox.sh fetch [board]            # download artifacts to artifacts/<board>/
bin/buildbox.sh tail [board]             # tail the build log
bin/buildbox.sh ssh                      # interactive shell
bin/buildbox.sh clean-artifacts          # remove all artifacts from buildbox
bin/buildbox.sh destroy                  # delete the buildbox VM
```

Available boards:

| Board | What it is |
|---|---|
| `pi-zero-2w` | Raspberry Pi Zero 2W SD card image |
| `rpi3` | Raspberry Pi 3 SD card image |
| `rpi4` | Raspberry Pi 4 SD card image |
| `qemu-arm64` | QEMU arm64 virtual machine image |

Set `BUILDBOX_HOST=<ip>` or add `buildbox` to `/etc/hosts`.

To run a QEMU build locally after fetching:

```bash
bin/run-qemu                             # runs artifacts/qemu-arm64/ by default
ssh admin@localhost -p 2222              # SSH once booted
```

### Write to SD card

```bash
gunzip -k artifacts/pi-zero-2w/offlinelab-rpi-pi-zero-2w-arm64*.img.gz
sudo dd if=artifacts/pi-zero-2w/offlinelab-rpi-pi-zero-2w-arm64*.img of=/dev/diskN bs=4M status=progress
```

## Config provisioning

Configuration is applied by `bootconf` (from `offlinelab-bootconf`), which reads
`/boot/firmware/bootconf.yaml` at every boot. Copy `bootconf.yaml.example` from the
boot partition to `bootconf.yaml` and fill in your SSH key and WiFi credentials.

The boot partition is FAT32 — it can be written from any OS before the card is inserted.
Bootconf is idempotent: existing `/data` files are not overwritten.

For development builds, bake an admin key directly into the image via `.config`:
```
BR2_PACKAGE_OFFLINELAB_ADMIN=y
BR2_PACKAGE_OFFLINELAB_ADMIN_AUTHORIZED_KEY="ssh-ed25519 AAAA... you@host"
```

SSH is provided by dropbear (key-only, no passwords). Connect as `admin` (uid 1000,
passwordless sudo). The host key is generated by bootconf on first boot and persists at
`/data/config/ssh/hostkey`.

## Console access

- **HDMI + USB keyboard** — login via getty@tty1 (USB port in OTG mode: keyboard OR
  gadget, not both simultaneously)
- **GPIO UART** (ttyS0) — connect to GPIO 14/15, 115200 baud
- **USB serial** (ttyGS0) — connect Pi's USB port to a computer (when no keyboard attached)

USB also provides an ethernet interface (usb0) at `10.55.0.1/24` with DHCP server.

## Data partition

Persistent storage at `/data`:
```
/data/
├── config/                    # provisioned system config
│   ├── wifi/                  # wpa_supplicant.conf
│   ├── ssh/hostkey            # dropbear host key
│   ├── firewall/rules.d/      # per-app nftables rule fragments
│   ├── system/machine-id      # stable machine-id across A/B slot switches
│   └── resources.json         # resource baseline (written at boot)
├── home/admin/                # admin user home directory
│   ├── .ssh/authorized_keys   # provisioned from boot partition via bootconf
│   ├── .config/
│   └── bin/                   # user scripts, on PATH
├── apps/                      # systemd portable service images (.raw)
└── extensions/
    ├── sysext/                # sysext images (bind-mounted to /var/lib/extensions)
    └── confext/               # confext images (bind-mounted to /etc/extensions)
```

`/var/lib/portables` is symlinked to `/data/apps`. `/var/lib/extensions` and
`/etc/extensions` are bind-mounted from `/data/extensions/sysext/` and
`/data/extensions/confext/` at sysinit.

The overlayfs upper/work dirs live on the dedicated overlay partition (p3, 96 MB),
not on `/data`. Each slot gets its own directory (`/overlay/a/`, `/overlay/b/`)
so overlay state doesn't leak between A/B slots.

## Packages

The OS is split into focused packages, each self-contained with its own systemd units,
scripts, and config:

| Package | Purpose |
|---------|---------|
| `offlinelab-base` | Boot-firmware mount, data partition expansion, sysext/confext bind mounts, power profile, serial console, /etc/issue |
| `offlinelab-admin` | Development admin user baked into rootfs at build time (do not use in production) |
| `offlinelab-bootconf` | Boot-time configuration: reads `/boot/firmware/bootconf.yaml` to apply SSH keys, WiFi, sudoers |
| `offlinelab-framework` | Bash utility library and `boxctl` CLI — installed to `/usr/lib/framework/` |
| `offlinelab-firewall` | nftables firewall — static rules on rootfs, per-app fragments under `/data/config/firewall/` |
| `offlinelab-usb-gadget` | USB composite gadget (ACM serial + ECM ethernet), ttyGS0, usb0 |
| `offlinelab-wifi` | WiFi via wpa_supplicant |
| `offlinelab-ssh` | Dropbear SSH server, key-only auth |
| `offlinelab-zram` | Compressed RAM swap for low-memory operation |
| `offlinelab-portable` | Systemd portable services, sysext, and confext support; `/data/apps` symlinks |
| `offlinelab-resources` | Resource baseline at boot — writes `/data/config/resources.json` |
| `offlinelab-update` | RAUC A/B OTA update integration, mark-good service |
| `offlinelab-disco` | Service discovery, NSS name resolution, time sync |

## Verification

```bash
bin/verify.sh artifacts/pi-zero-2w/
bin/verify.sh artifacts/qemu-arm64/
```

Inspects built artifacts without hardware: partition layout, boot contents, initramfs,
rootfs (systemd units, scripts, users), and kernel config.

## Documentation

The documentation site is built with [Zensical](https://zensical.dev) and deployed to
GitHub Pages on every push to `main`.

```bash
uv run bin/docs.py          # build site to docs/public/
uv run bin/docs.py serve    # serve locally on :8000
```

- [docs/KERNEL.md](docs/KERNEL.md) — kernel strategy and trimming plan

## License

GPL-2.0-only — Copyright (C) 2025-2026 Offline Lab
