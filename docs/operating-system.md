# Operating System

The base OS (**Offline Lab OS**) is a minimal read-only Linux image built with Buildroot. Its job is to boot the hardware, provide connectivity, and host portable services.

## Design principles

**Read-only root.** The root partition is mounted read-only. Writable paths are provided via overlayfs, with the upper layer on a dedicated partition.

**Systemd everywhere.** Systemd handles init, services, networking, mounts, and timers. Minimal other configuration.

**Offline-first.** No network dependencies at boot. No NTP, no connectivity checks, no waiting for DHCP before reaching multi-user.

**Bare minimum.** Only what is needed to boot, connect to WiFi, and run portable services. Everything else ships as a service image.

## Build system

Offline Lab OS is built with [Buildroot](https://buildroot.org/). Builds run in Docker on macOS or on a native arm64 Debian VM (the "buildbox"). Multiple boards are supported; each has its own defconfig under `br2-external/configs/`.

The [builder repository](https://github.com/offline-lab/builder) contains the Buildroot configuration, external tree, and tooling for producing SD card images.

## Kernel

**RPi boards** use the Raspberry Pi foundation kernel (`raspberrypi/linux`, `rpi-6.12.y`) for hardware support: WiFi, Bluetooth, HDMI, and USB device tree overlays. The kernel config is trimmed from `bcm2711_defconfig`, reducing the module directory from ~100 MB to ~17 MB and cutting build time significantly.

**QEMU** uses the mainline kernel (`arm64 defconfig`) with a small hardware fragment enabling virtio block, virtio net, and the PL011 UART.

Key built-in options on all boards: overlayfs, initramfs, zram.

## Partitions

The SD card uses MBR partitioning with an extended partition to hold logical volumes:

**Primary partitions**

| # | Name | Type | Size | Contents |
|---|------|------|------|----------|
| p1 | boot | FAT32 | 32 MB | firmware, U-Boot, initramfs, boot.scr |
| p2 | *(extended)* | — | — | container for logical partitions |
| p3 | overlay | ext4 | 96 MB | per-slot overlayfs upper+work dirs |
| p4 | data | ext4 | 64 MB+ | persistent storage (expanded on first boot) |

**Logical partitions (inside p2)**

| # | Name | Type | Size | Contents |
|---|------|------|------|----------|
| p5 | kernel-a | sqfs | 24 MB | kernel Image (slot A) |
| p6 | rootfs-a | ext4 | 512 MB | root filesystem (slot A) |
| p7 | kernel-b | sqfs | 24 MB | kernel Image (slot B) |
| p8 | rootfs-b | ext4 | 512 MB | root filesystem (slot B) |
| p9 | bootstate | raw | 8 MB | U-Boot env: slot order, boot counters |

See [Boot](boot.md) for a detailed walkthrough of the boot sequence and A/B mechanics.

## Root filesystem

The active root partition is ext4, mounted read-only. An overlayfs layer sits on top, with:

- **Lower:** the read-only rootfs (slot A or B)
- **Upper/work:** per-slot directories on the dedicated overlay partition (`/overlay/a/` or `/overlay/b/`)

From systemd's perspective the root appears writable, but all writes land on the overlay partition. The read-only rootfs is never modified.

The overlay partition is separate from `/data` to keep user data isolated from OS state, and to allow each A/B slot to have its own overlay. A kernel or rootfs update doesn't carry stale overlay state from the previous slot.

tmpfs is not used as the overlay upper; on a 512MB device that would consume RAM better spent on services.

## A/B updates

Two root partitions allow atomic, rollback-capable updates. The inactive slot is updated while the system runs from the active slot. On reboot, U-Boot switches to the new slot.

U-Boot reads a boot counter from the bootstate partition. If the new slot fails to boot `N` times, U-Boot falls back to the previous slot automatically. Once the system reaches multi-user.target, a systemd service marks the boot successful and resets the counter.

## First boot

On first boot, the data partition is resized to fill the remaining SD card space and formatted. This is automatic: if the partition can't be mounted because there's no filesystem, resize and format run before systemd continues.

Other first-boot setup: machine-id generation, SSH host key generation, config file provisioning from the boot partition. Each is idempotent: if the expected file already exists in `/data`, the setup step is skipped.

## WiFi

WiFi is configured via `bootconf.yaml` on the FAT32 boot partition. Mount the SD card on any computer, copy `bootconf.yaml.example` to `bootconf.yaml`, and fill in the SSID and PSK hash. No serial console or screen needed.

`bootconf.service` reads the file at every boot and writes credentials to `/data/config/wifi/wpa_supplicant.conf` if not already present. See [Configuration](configuration.md) for the full `bootconf.yaml` reference.

## Systemd usage

The OS uses systemd for:

- Init and service management
- Network configuration (systemd-networkd)
- Mount management (overlayfs, data partition, boot partition)
- Boot-time configuration (`bootconf`)
- Boot success signaling for A/B updates
- Portable service hosting
