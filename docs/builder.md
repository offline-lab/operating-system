# Building the OS

The OS image is built with Buildroot. There are two build paths:

- **Docker** — runs an arm64 build container on macOS (slow, via emulation)
- **Buildbox** — a native arm64 Debian VM for fast builds

Both produce the same output: a compressed SD card image in `artifacts/`.

## Prerequisites

**Docker path:**
- Docker Desktop with `linux/arm64` platform support enabled
- ~15GB free disk for the build cache

**Buildbox path:**
- UTM (macOS virtualisation) or any arm64 Debian host
- SSH access to the VM (`buildbox` in `/etc/hosts` or `BUILDBOX_HOST` env var)
- ~15GB free disk on the VM

## Setup

```bash
git clone https://github.com/offline-lab/builder
cd builder

cp env.example .env
cp config.example .config
# Edit .env and .config — see Configuration below
```

## Docker build

```bash
# Build the Docker image (first time only, or after Dockerfile changes)
bin/builder.sh --build-docker

# Run a full build
bin/builder.sh --build

# Open a shell in the build container
bin/builder.sh --shell
# Inside: bin/build.sh
```

The build writes artifacts to `artifacts/` on the host.

## Buildbox build

The buildbox is a native arm64 Debian VM provisioned with cloud-init. It is significantly faster than Docker on Apple Silicon because there's no emulation overhead.

```bash
# Create a new VM (UTM, provisioned via cloud-init)
bin/buildbox.sh create

# Full pipeline: sync code, build, verify, download artifacts
bin/buildbox.sh

# Individual steps
bin/buildbox.sh sync      # push local repo to buildbox
bin/buildbox.sh build     # sync + build
bin/buildbox.sh verify    # run verification on artifacts
bin/buildbox.sh fetch     # download artifacts to local artifacts/
bin/buildbox.sh ssh       # open an interactive shell
```

Set `BUILDBOX_HOST=<ip>` in `.env` or add `buildbox` to `/etc/hosts`.

## Configuration

Copy `config.example` to `.config`. Options set here are applied at build time:

```ini
# WiFi (baked into the image)
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_CREATE=y
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_SSID="your-network"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_PASSWORD="your-password"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_COUNTRY="NL"

# SSH authorized keys (baked into the image)
BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS=y
BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS_CONTENT="ssh-ed25519 AAAA... you@host"
```

These options embed credentials in the built image. Treat the `.config` file and the resulting image as sensitive. The `.config` file is gitignored.

See [Configuration](configuration.md) for a full option reference and the boot-partition alternative.

## Writing to SD card

```bash
# Decompress the image (keeps the .gz)
gunzip -k artifacts/offlinelab-sdcard-*.img.gz

# Write to SD card (replace diskN with your device)
sudo dd if=artifacts/offlinelab-sdcard-*.img of=/dev/diskN bs=4M status=progress
```

On macOS, use `diskutil list` to identify the SD card device. Unmount it first with `diskutil unmountDisk /dev/diskN`.

## Verification

After a build, `bin/verify.sh` inspects the artifacts without hardware:

```bash
bin/verify.sh artifacts/
```

This checks partition layout, boot partition contents, initramfs structure, rootfs (systemd units, scripts, users), kernel config options, and module dependencies. It does not boot the image.

## Gotchas

**Editing br2-external source files.** Buildroot caches package output and won't re-run install steps if the source timestamp hasn't changed in a way it detects. After editing files under `br2-external/package/offlinelab-*/src/`, run:

```bash
make offlinelab-<package>-dirclean
```

Then rebuild. Without this, your changes won't appear in the image.

**Build cache is large.** The first build downloads and compiles the entire toolchain, kernel, and all packages. This takes 30–60 minutes and uses ~15GB. Subsequent builds are fast (minutes) because Buildroot only rebuilds what changed.

**Credentials in .config vs boot partition.** Build-time credentials (`.config` options) are baked into the image and present on every SD card flashed from that image. Boot-partition provisioning is per-card. Use build-time options for development; use boot-partition files for deployment. See [Configuration](configuration.md).
