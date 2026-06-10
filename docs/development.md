# Development guide

A guide for contributors working on the OS image, framework, and packages.

## Quick start

For build environment setup (Docker or Buildbox), see [Build the OS image](build-image.md).

This page covers the development workflow after your build environment is working: making changes and common pitfalls. See the [Style guide](styleguide.md) for coding conventions.

## Making changes

### Rebuilding after edits

Buildroot caches package output. After editing files under `br2-external/`, force a clean rebuild:

```bash
make offlinelab-<package>-dirclean
```

Then rebuild. Without this, your changes won't appear in the image. This is the most common source of "my change isn't in the image" confusion.

### Framework development

The framework (`framework/`) is first-party source. Edit it directly in this repo, then rebuild:

```bash
make offlinelab-framework-dirclean && make offlinelab-framework
```

For framework development without full OS rebuilds, use the framework's dev setup:

```bash
source framework/bin/dev-setup
bin/test-framework --lint
```

See `framework/.claude/CLAUDE.md` for the full framework development guide including function conventions, variable namespace, and module structure.

## Critical gotchas

### Config provisioning is idempotent

Boot-time configuration is applied by `bootconf` reading `/boot/firmware/bootconf.yaml` at every boot. If the target file already exists in `/data`, `bootconf` leaves it unchanged.

To re-provision a setting: delete the live file from `/data` and reboot.

To re-provision a flashed card: delete the file from `/data` (requires booting the device first), or reflash.

### USB OTG: keyboard or gadget, not both

The Zero 2W has one USB port in OTG mode. It can act as a USB host (keyboard, USB drives) or as a USB gadget (serial + ethernet), but not both simultaneously.

The `usb-gadget.sh` script detects whether a USB host device is already connected and skips gadget setup if so. This means: if you plug a keyboard in before boot, the USB gadget interfaces (ttyGS0, usb0) will not come up.

### Overlayfs upper is on the overlay partition

The overlayfs upper directory is `/overlay/a/upper` or `/overlay/b/upper` on the dedicated overlay partition (`p3`), not on `/data`. Changes to rootfs-managed paths (anything not under `/data`) land on the overlay partition.

If you see unexpected state persisting across rootfs updates, check the overlay partition, not `/data`.

### machine-id persists via /data

On every boot the initramfs clears the overlay upper directory and restores `/etc/machine-id` from `/data/config/system/machine-id`. On first boot, `persist-machine-id.service` writes the machine-id to `/data` so it survives subsequent slot switches and overlay resets. The framework function `machine_id::persist` (in `system.sh`) handles the persistence logic.

## Verification

`bin/verify.sh` runs 200+ checks against the build artifacts without requiring hardware:

```bash
bin/verify.sh artifacts/
```

Checks include:

- Partition layout and types
- Boot partition contents (U-Boot, boot.scr, kernel sqfs, initramfs)
- Initramfs structure (static busybox, init script, overlayfs logic)
- Rootfs contents (all systemd units enabled, scripts installed, users present)
- Kernel config (built-in options: overlayfs, DWC2, zram, MMC)
- Module dependencies (modules.dep populated, XZ decompression available)
- A/B boot logic assertions

Add new checks to `bin/verify.sh` when adding new packages or changing the image structure.

## Adding a package

1. Create `br2-external/package/offlinelab-<name>/`:
   - `Config.in`: Buildroot Kconfig options
   - `offlinelab-<name>.mk`: install rules
   - `src/`: source files (scripts, systemd units, config)

2. Register in `br2-external/Config.in`:
   ```
   source "package/offlinelab-<name>/Config.in"
   ```

3. Enable in the defconfig:
   ```
   BR2_PACKAGE_OFFLINELAB_<NAME>=y
   ```

4. Add verification checks to `bin/verify.sh`.

Follow the pattern of an existing package. Keep each package focused on one concern. Use the provisioning pattern for any config that users might need to change (boot partition to `/data`).
