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
│   ├── build-native.sh           # build script (runs on buildbox VM)
│   ├── clean.sh                  # buildroot distclean
│   ├── verify.sh                 # automated image verification
│   └── buildbox/cloud-init/      # cloud-init data for buildbox VM
├── br2-external/                 # buildroot external tree
│   ├── boards/pi-zero-2w/        # board support (config.txt, initramfs, etc.)
│   ├── configs/                  # buildroot defconfigs
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
# Create a new buildbox VM (UTM, cloud-init provisioned)
bin/buildbox.sh create

# Full pipeline: sync code, build, verify, fetch artifacts
bin/buildbox.sh

# Or run steps individually
bin/buildbox.sh sync      # push code to buildbox
bin/buildbox.sh build     # sync + build
bin/buildbox.sh verify    # run verification
bin/buildbox.sh fetch     # download artifacts
bin/buildbox.sh ssh       # interactive shell
```

Set `BUILDBOX_HOST=<ip>` or add `buildbox` to `/etc/hosts`.

### Write to SD card

```bash
gunzip -k artifacts/offlinelab-sdcard-*.img.gz
sudo dd if=artifacts/offlinelab-sdcard-*.img of=/dev/diskN bs=4M status=progress
```

## Config provisioning

Configuration files placed in the `config/` directory on the boot partition (FAT32,
accessible from any OS) are provisioned to `/data/` on first boot. The persistent copy
is authoritative — to re-provision, delete the persistent copy and place a new file on boot.

```
/boot/firmware/config/wpa_supplicant.conf  →  /data/config/wifi/wpa_supplicant.conf
/boot/firmware/config/authorized_keys      →  /data/home/admin/.ssh/authorized_keys
```

## WiFi setup

Place a `wpa_supplicant.conf` file in the `config/` directory on the boot partition:

```
ctrl_interface=DIR=/run/wpa_supplicant GROUP=netdev
update_config=1
country=NL

network={
    ssid="your-network"
    psk="your-password"
}
```

**Multi-network:** drop multiple `wpa_supplicant-*.conf` files (e.g. `wpa_supplicant-home.conf`,
`wpa_supplicant-work.conf`). They are merged in alphabetical order; control priority via the
`priority=` field within each `network {}` block.

Or configure WiFi at build time via `.config`:
```
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_CREATE=y
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_SSID="your-network"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_PASSWORD="your-password"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_COUNTRY="NL"
```

## SSH access

SSH is provided by dropbear with key-only authentication (no passwords).

Place an `authorized_keys` file in `config/` on the boot partition, or configure at build time:
```
BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS=y
BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS_CONTENT="ssh-ed25519 AAAA... you@host"
```

Host keys are generated on first boot and persist at `/data/config/ssh/dropbear/`.
Connect as the `admin` user (uid 1000, passwordless sudo).

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
│   ├── ssh/dropbear/          # dropbear host keys
│   └── fake-hwclock.data      # last-known time (persisted each shutdown)
├── home/admin/                # admin user home directory
│   ├── .ssh/authorized_keys   # provisioned from boot partition
│   ├── .config/
│   └── bin/                   # user scripts, on PATH
├── apps/                      # systemd portable service images (.raw)
├── extensions/                # systemd sysext images
└── confexts/                  # systemd confext images
```

`/var/lib/portables`, `/var/lib/extensions`, and `/var/lib/confexts` are symlinked
to their `/data/` counterparts so images survive across reboots.

The overlayfs upper/work dirs live on the dedicated overlay partition (p3),
not on `/data`. Each slot gets its own directory (`/overlay/a/`, `/overlay/b/`)
so overlay state doesn't leak between A/B slots.

## Packages

The OS is split into focused packages, each self-contained with its own systemd units,
scripts, and config:

| Package | Purpose |
|---------|---------|
| `offlinelab-base` | Boot-firmware mount, data partition expansion, fake-hwclock, power profile, serial console, /etc/issue |
| `offlinelab-framework` | Bash utility library and `boxctl` CLI — installed to `/usr/lib/framework/` |
| `offlinelab-usb-gadget` | USB composite gadget (ACM serial + ECM ethernet), ttyGS0, usb0 |
| `offlinelab-wifi` | WiFi via wpa_supplicant, config provisioning from boot partition |
| `offlinelab-ssh` | Dropbear SSH server, key-only auth, key provisioning from boot partition |
| `offlinelab-zram` | Compressed RAM swap for low-memory operation |
| `offlinelab-portable` | Systemd portable services, sysext, and confext support; `/data/apps` symlinks |
| `offlinelab-update` | RAUC A/B OTA update integration, mark-good service |
| `offlinelab-disco` | Service discovery, NSS name resolution, time sync |

## Verification

```bash
bin/verify.sh artifacts/
```

Inspects built artifacts without hardware: partition layout, boot contents, initramfs,
rootfs (systemd units, scripts, users), and kernel config.

## Documentation

The documentation site is built with [Zensical](https://zensical.dev) and deployed to
GitHub Pages on every push to `main`.

```bash
uv run bin/docs.py          # build site to docs/public/
uv run bin/docs.py serve    # serve locally on :8000
bin/generate-framework-docs # regenerate framework API reference (docs/framework/)
```

- [docs/KERNEL.md](docs/KERNEL.md) — kernel strategy and trimming plan

## License

GPL-2.0-only — Copyright (C) 2025-2026 Offline Lab
