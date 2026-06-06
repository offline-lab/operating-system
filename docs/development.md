# Development guide

A guide for contributors working on the OS image, framework, and packages.

## Quick start

For build environment setup (Docker or Buildbox), see [Build the OS image](build-image.md).

This page covers the development workflow after your build environment is working: making changes, coding conventions, and common pitfalls.

## Repository structure

```
builder/
├── bin/
│   ├── builder.sh              # Docker build environment wrapper
│   ├── buildbox.sh             # Lima VM management and build pipeline
│   ├── build.sh                # build script (runs inside Docker)
│   ├── build-image.sh          # per-board build script (runs on buildbox)
│   ├── clean.sh                # buildroot distclean
│   ├── verify.sh               # automated artifact inspection (200+ checks)
│   ├── run-qemu                # run a built QEMU image locally
│   ├── test-qemu-ota           # end-to-end OTA test in QEMU
│   ├── test-framework          # framework lint and unit tests
│   ├── generate-framework-docs # rebuild docs/framework/ from source
│   ├── lib/                    # shared bash library for bin/ scripts
│   └── buildbox/
│       └── cloud-init/         # cloud-init for the Lima buildbox VM
├── br2-external/
│   ├── boards/
│   │   ├── common/             # shared across all boards
│   │   │   ├── fragments/      # busybox.config, linux-kernel.config
│   │   │   ├── genimage.cfg.in # partition layout template
│   │   │   ├── initramfs/      # initramfs init script
│   │   │   └── splash.{png,svg} # psplash boot image
│   │   ├── rpi/                # RPi family shared files
│   │   │   ├── fragments/      # linux-hardware.config
│   │   │   ├── hook.sh         # post-image hook (all RPi boards)
│   │   │   ├── uboot/boot.cmd  # U-Boot A/B boot script
│   │   │   ├── pi-zero-2w/     # Pi Zero 2W board
│   │   │   │   ├── fragments/  # uboot-fragment.config
│   │   │   │   ├── meta        # board identity (image name, compatible string)
│   │   │   │   ├── cmdline.txt
│   │   │   │   └── config.txt  # RPi firmware config
│   │   │   ├── rpi3/           # Raspberry Pi 3
│   │   │   └── rpi4/           # Raspberry Pi 4
│   │   ├── qemu/               # QEMU family shared files
│   │   │   ├── hook.sh         # post-image hook (all QEMU boards)
│   │   │   ├── uboot/boot.cmd  # U-Boot A/B boot script
│   │   │   └── arm64/          # QEMU arm64 board
│   │   │       ├── fragments/  # linux-hardware.config, uboot-fragment.config
│   │   │       └── meta        # board identity
│   │   └── scripts/            # shared post-build/post-image scripts
│   │       ├── post-build.sh
│   │       ├── post-image-lib.sh
│   │       └── post-image.sh
│   ├── configs/                # one defconfig per board
│   │   ├── offlinelab_pi_zero_2w_defconfig
│   │   ├── offlinelab_rpi3_defconfig
│   │   ├── offlinelab_rpi4_defconfig
│   │   └── offlinelab_qemu_arm64_defconfig
│   ├── package/
│   │   └── offlinelab-*/       # OS packages
│   ├── rootfs_overlay/         # static files merged into rootfs
│   ├── skeleton/               # custom rootfs directory skeleton
│   ├── Config.in               # top-level Kconfig
│   ├── external.desc
│   ├── external.mk
│   ├── users.txt               # user accounts
│   └── devices.txt             # device nodes
├── framework/                  # first-party Bash utility library and boxctl CLI
├── docs/                       # documentation site (Zensical)
├── Dockerfile
├── config.example              # build-time config template
└── env.example                 # environment template
```

No binaries, pre-built images, or third-party source code is stored in git. Build artifacts go to `artifacts/` (gitignored). External dependencies are fetched at build time.

## Making changes

### Rebuilding after edits

Buildroot caches package output. After editing files under `br2-external/`, force a clean rebuild:

```bash
make offlinelab-<package>-dirclean
```

Then rebuild. Without this, your changes won't appear in the image. This is the most common source of "my change isn't in the image" confusion.

### Framework development

The framework (`framework/`) is first-party source — edit it directly in this repo, then rebuild:

```bash
make offlinelab-framework-dirclean && make offlinelab-framework
```

For framework development without full OS rebuilds, use the framework's dev setup:

```bash
source framework/bin/dev-setup
bin/test-framework --lint
```

See `framework/.claude/CLAUDE.md` for the full framework development guide including function conventions, variable namespace, and module structure.

## Coding conventions

- **Shell scripts:** POSIX sh where possible, bash only when needed. No unofficial bash-isms.
- **Systemd units:** explicit `After=`, `Requires=`, `WantedBy=`. Don't rely on implicit ordering.
- **Config files:** match the style of the file you're editing.
- **No binaries in git.** Everything fetched at build time.
- **Framework scripts** must follow the conventions in `framework/.claude/CLAUDE.md`: `namespace::function_name` naming, `log::trace` as first line, return codes 0/1/2.
- **Use the framework library** for common operations (logging, config reads, network checks, privilege escalation) rather than reimplementing them in package scripts.
- **Busybox compatibility:** `grep -E` not `grep -P`, `date -u` not `date --universal`, `mktemp -t prefix-XXXX` not `mktemp --suffix`. No gawk-specific features.
- Run `bin/test-framework --lint` before submitting changes to framework code.
- Read the `.claude/` and `AGENTS.md` files — they contain project-specific rules that apply to all contributions.

## Critical gotchas

### Config provisioning is first-boot-only

The provisioning services (`provision-wifi`, `provision-ssh`) run once. If the destination file already exists in `/data`, they exit without doing anything.

To re-provision a running device: delete the live file from `/data` and reboot.

To re-provision a flashed card: delete the file from `/data` (requires booting the device first), or reflash.

### USB OTG: keyboard or gadget, not both

The Zero 2W has one USB port in OTG mode. It can act as a USB host (keyboard, USB drives) or as a USB gadget (serial + ethernet), but not both simultaneously.

The `usb-gadget.sh` script detects whether a USB host device is already connected and skips gadget setup if so. This means: if you plug a keyboard in before boot, the USB gadget interfaces (ttyGS0, usb0) will not come up.

### Overlayfs upper is on the overlay partition

The overlayfs upper directory is `/overlay/a/upper` or `/overlay/b/upper` on the dedicated overlay partition (`p3`), not on `/data`. Changes to rootfs-managed paths (anything not under `/data`) land on the overlay partition.

If you see unexpected state persisting across rootfs updates, check the overlay partition, not `/data`.

### machine-id lives in bootstate

The machine-id is stored in the U-Boot environment on the bootstate partition (`p9`), not on `/data` or in `/etc/machine-id` on the rootfs. It persists across A/B slot switches and is the same regardless of which slot is active.

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
   - `Config.in` — Buildroot Kconfig options
   - `offlinelab-<name>.mk` — install rules
   - `src/` — source files (scripts, systemd units, config)

2. Register in `br2-external/Config.in`:
   ```
   source "package/offlinelab-<name>/Config.in"
   ```

3. Enable in the defconfig:
   ```
   BR2_PACKAGE_OFFLINELAB_<NAME>=y
   ```

4. Add verification checks to `bin/verify.sh`.

Follow the pattern of an existing package. Keep each package focused on one concern. Use the provisioning pattern for any config that users might need to change (boot partition → `/data`).
