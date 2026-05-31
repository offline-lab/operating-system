# Boot

This page describes how the system boots, how the A/B slot mechanism works, and what happens on first boot.

## Boot chain

```
RPi firmware (bootcode.bin → start.elf)
  └─ loads U-Boot (u-boot.bin from boot partition)
       └─ runs boot.scr
            └─ reads bootstate (p9), selects slot A or B
                 └─ loads kernel from kernel-a or kernel-b (squashfs)
                      └─ loads initramfs from boot partition
                           └─ mounts rootfs read-only
                                └─ mounts overlayfs (upper on overlay partition)
                                     └─ mounts data partition
                                          └─ switch_root → systemd
```

No U-Boot shell, no GRUB, no splash screen at this stage. The terminal shows U-Boot output followed by kernel boot messages until systemd takes over.

## Partition layout

```
Primary:
  p1  boot       FAT32   32MB    firmware, U-Boot, initramfs, boot.scr, config files
  p2  (extended)                 container for logical partitions
  p3  overlay    ext4    96MB    per-slot overlayfs upper/work directories
  p4  data       ext4   64MB+   persistent user data (expanded on first boot)

Logical (inside p2):
  p5  kernel-a   sqfs   24MB    kernel Image, DTBs (slot A)
  p6  rootfs-a   ext4  512MB    root filesystem (slot A)
  p7  kernel-b   sqfs   24MB    kernel Image, DTBs (slot B)
  p8  rootfs-b   ext4  512MB    root filesystem (slot B)
  p9  bootstate  raw     8MB    U-Boot environment: BOOT_ORDER, boot counters
```

## U-Boot boot logic

U-Boot runs `boot.scr` (compiled from `boot.cmd`). The script implements an A/B bootchooser:

1. Read `BOOT_ORDER` from the bootstate env (e.g. `A B` or `B A`).
2. For each slot in order, check its boot counter. If the counter is zero, skip the slot (exhausted).
3. Decrement the counter for the selected slot and save it back to bootstate.
4. Load the kernel from the selected slot's squashfs partition.
5. Pass `rauc.slot=A` or `rauc.slot=B` on the kernel command line.

If both slots are exhausted (counters at zero), U-Boot resets both counters and retries, preferring whichever slot is first in `BOOT_ORDER`.

## Boot success signaling

The initramfs passes `rauc.slot=A|B` through to userspace via the kernel command line. After reaching multi-user.target, a systemd service (`rauc-mark-good.service`) reads this value and marks the active slot as good by resetting its boot counter to the configured maximum. This service is part of Phase 1 and is not yet in the image.

If the system crashes or panics before reaching multi-user.target, the counter stays decremented. After enough failures, U-Boot switches to the other slot.

## Initramfs

The initramfs is a small static busybox environment. The `init` script:

1. Mounts `proc`, `sys`, `dev`.
2. Waits for the MMC device to appear.
3. Reads `rauc.slot` from `/proc/cmdline` to determine which slot to boot.
4. Mounts the selected rootfs read-only.
5. Mounts the overlay partition (`/dev/mmcblk0p3`).
6. Creates per-slot upper/work directories on the overlay partition if they don't exist (`/overlay/a/upper`, `/overlay/a/work`).
7. Sets up overlayfs with lower=rootfs, upper and work from the overlay partition.
8. Mounts the data partition (`/dev/mmcblk0p4`) at `/data` inside the new root.
9. Runs `switch_root` to hand off to systemd.

The static busybox binary is embedded in the initramfs. There are no external dependencies.

## Overlayfs design

The overlay partition (`p3`) exists separately from `/data` for two reasons:

- **Slot isolation.** Each A/B slot gets its own upper/work directory. Switching slots doesn't carry stale OS-level write state from the previous slot.
- **Data separation.** User data on `/data` is independent of the OS overlay. An OS update doesn't touch user data, and user data doesn't bleed into the OS layer.

The upper is **not** tmpfs. On a 512MB device, using RAM for the overlay upper would be wasteful. The overlay partition is on SD card, same as everything else.

After a successful A/B slot switch, the old slot's overlay directory is left as-is. It can be cleared manually or will be reinitialised on the next write.

## First boot

When the data partition has no filesystem (fresh SD card write), the initramfs detects this and hands off to `expand-data.sh` in the early boot sequence instead of continuing normally.

`expand-data.sh` (from `offlinelab-base`):

1. Resizes the data partition to fill the remaining SD card space using `parted` and `resize2fs`.
2. Formats and mounts the partition.
3. Creates the `/data` directory structure: `config/`, `home/app/`, `portable/`.
4. Creates the app user's `.bashrc`.

After `expand-data.sh` completes, boot continues normally.

First-boot provisioning (WiFi credentials, SSH keys) runs as separate systemd services after the data partition is available. See [Configuration](configuration.md).

## Boot partition contents

```
/boot/firmware/
├── config/                     # user-supplied config (provisioned on first boot)
│   ├── authorized_keys         # optional — SSH public keys
│   └── wpa_supplicant.conf     # optional — WiFi credentials
├── overlays/                   # RPi device tree overlays
├── bcm2710-rpi-zero-2-w.dtb    # device tree blob
├── bootcode.bin                # RPi first-stage bootloader
├── boot.scr                    # U-Boot script (compiled from boot.cmd)
├── cmdline.txt                 # kernel command line
├── config.txt                  # RPi firmware config
├── fixup.dat                   # RPi firmware fixup
├── initramfs.cpio.gz           # initramfs
├── start.elf                   # RPi VideoCore firmware
└── u-boot.bin                  # U-Boot
```

The boot partition is mounted read-only at `/boot/firmware` by `boot-firmware.mount`. It is not written to at runtime.

## Trade-offs

**Shared bootloader.** U-Boot lives on the boot partition and is shared between slots. A bad U-Boot update affects both slots. This is a known limitation — per-slot bootloaders would require a more complex partition layout.

**Kernel per slot.** Each slot has its own kernel squashfs, so a kernel update is contained to the inactive slot and follows the same A/B rollback path as a rootfs update.

**Overlay persistence.** After a rootfs update, the old slot's overlay directory is not automatically cleared. If the slot is later activated again, it may see stale overlay state. Manual cleanup is required.

**No boot splash yet.** psplash integration is planned for a later phase.
