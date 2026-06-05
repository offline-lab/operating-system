# Build the image

The OS image is built with Buildroot. There are two build paths:

- **Docker** — runs an arm64 build container on macOS (via QEMU emulation, slower)
- **Buildbox** — a native arm64 Debian VM for fast builds on Apple Silicon

Both produce the same output: a compressed SD card image in `artifacts/`.

## Prerequisites

**Docker path:**
- Docker Desktop with `linux/arm64` platform support enabled
- ~15 GB free disk for the build cache

**Buildbox path:**
- Lima (`limactl`) or any arm64 Debian host
- SSH access to the VM (`buildbox` in `/etc/hosts` or `BUILDBOX_HOST` env var)
- ~15 GB free disk on the VM

## Setup

Clone the repository and copy the example config files:

```bash
git clone https://github.com/offline-lab/builder
cd builder

cp env.example .env
cp config.example .config
```

Open `.config` and set at minimum your WiFi credentials and SSH authorized key. These are baked into the image at build time:

```ini
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_CREATE=y
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_SSID="your-network"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_PASSWORD="your-password"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_COUNTRY="NL"

BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS=y
BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS_CONTENT="ssh-ed25519 AAAA... you@host"
```

The `.config` file is gitignored — treat it as sensitive. See [Configuration](configuration.md) for all available options and the boot-partition alternative.

## Docker build

Docker is the easiest path if you're on macOS and just want to try a build. It runs arm64 in emulation via QEMU, which works correctly but is slow — expect a first build to take 45–90 minutes.

```bash
# Build the Docker image (first time only, or after Dockerfile changes)
bin/builder.sh --build-docker

# Run a full build
bin/builder.sh --build
```

The image file lands in `artifacts/offlinelab-sdcard-<date>.img.gz`.

To open a shell inside the build container for debugging:

```bash
bin/builder.sh --shell
# Inside the container:
bin/build.sh
```

## Buildbox build

Buildbox is a native arm64 Debian VM. Because there's no emulation overhead, it's significantly faster than Docker on Apple Silicon — typically 3–5× faster.

### First-time setup

Create the VM using the bundled cloud-init config:

```bash
bin/buildbox.sh create
```

This provisions the VM with the right dependencies via cloud-init. Set the VM's IP in `.env` as `BUILDBOX_HOST=<ip>` or add `buildbox` to `/etc/hosts`:

```bash
echo "192.168.64.X  buildbox" | sudo tee -a /etc/hosts
```

### Available boards

| Board | Defconfig | Artifact path | Image type |
|---|---|---|---|
| `pi-zero-2w` | `offlinelab_pi_zero_2w_defconfig` | `artifacts/pi-zero-2w/` | SD card image + RAUC bundle |
| `qemu-arm64` | `offlinelab_qemu_arm64_defconfig` | `artifacts/qemu-arm64/` | QEMU disk image + U-Boot |

Each board gets its own output directory (`~/buildroot-<board>/`) and artifact path so builds don't clobber each other.

### Running a build

All `buildbox.sh` commands accept an optional `[board]` argument. Default is `pi-zero-2w`.

```bash
# Full pipeline (pi-zero-2w): sync → build → verify → fetch
bin/buildbox.sh

# Full pipeline for a specific board
bin/buildbox.sh qemu-arm64

# Or run steps individually
bin/buildbox.sh sync                        # push local repo to buildbox
bin/buildbox.sh build                       # build pi-zero-2w (default)
bin/buildbox.sh build qemu-arm64            # build QEMU image
bin/buildbox.sh verify [board]              # run verification checks
bin/buildbox.sh fetch [board]               # download artifacts to local machine
bin/buildbox.sh ssh                         # open an interactive shell
```

Artifacts land in `artifacts/<board>/` on your local machine after `fetch`.

### Running a QEMU image locally

After fetching the QEMU artifacts:

```bash
bin/run-qemu
# or: bin/run-qemu artifacts/qemu-arm64/

# SSH into the running VM (once booted):
ssh admin@localhost -p 2222
```

Expected service failures in QEMU (no hardware): `usb-gadget.service`, `wifi-setup.service`, `psplash.service`. Everything else should start normally.

## Writing to SD card

```bash
# Decompress the image (keeps the .gz)
gunzip -k artifacts/offlinelab-sdcard-*.img.gz

# Write to SD card (replace diskN with your device)
sudo dd if=artifacts/offlinelab-sdcard-*.img of=/dev/diskN bs=4M status=progress
```

On macOS, use `diskutil list` to identify the SD card device. Unmount it first with `diskutil unmountDisk /dev/diskN`.

## Verification

`bin/verify.sh` checks the artifacts without needing hardware:

```bash
bin/verify.sh artifacts/pi-zero-2w/
bin/verify.sh artifacts/qemu-arm64/
```

It inspects partition layout, boot contents, initramfs structure, rootfs, systemd units, kernel config, and module dependencies. It does not boot the image.

## Common issues

**Buildroot doesn't pick up your source changes** — Buildroot caches package output and won't re-run install steps if it doesn't detect a change. After editing files under `br2-external/package/offlinelab-*/src/`, force a rebuild:

```bash
make offlinelab-<package>-dirclean
```

Then run the build again. Without this, your changes won't appear in the image.

**First build takes very long** — expected. The first run downloads and compiles the full toolchain, kernel, and all packages from source. This takes 30–90 minutes depending on your machine and uses ~15 GB. Subsequent builds only rebuild what changed.

**Docker build fails with `exec format error`** — Docker Desktop doesn't have the arm64 emulation layer enabled. Go to Docker Desktop → Settings → Features in development → enable Rosetta for x86/amd64 emulation, or enable QEMU under experimental features.

**Credentials in `.config` vs boot partition** — Build-time credentials (`.config` options) are baked into the image and present on every SD card flashed from that image. Boot-partition provisioning is per-card. Use build-time options for development; use boot-partition files for deployment. See [Configuration](configuration.md).
