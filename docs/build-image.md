# Build the image

The OS image is built with Buildroot. There are two build paths: Docker and Buildbox. Both produce the same output — a compressed SD card image in `artifacts/`.

## Before you start

Clone the repository and copy the example config files:

```bash
git clone https://github.com/offline-lab/builder
cd builder

cp env.example .env
cp config.example .config
```

Open `.config` and set at minimum your WiFi credentials and SSH authorized key:

```ini
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_SSID="your-network"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_PASSWORD="your-password"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_COUNTRY="NL"

BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS=y
BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS_CONTENT="ssh-ed25519 AAAA... you@host"
```

These are baked into the image. The `.config` file is gitignored — treat it as sensitive. See [Configuration](configuration.md) for all available options.

## Docker

Docker is the easiest path if you're on macOS and just want to try a build. It runs arm64 in emulation via QEMU, which works correctly but is slow — expect a first build to take 45–90 minutes.

**Prerequisites:** Docker Desktop with `linux/arm64` platform support, ~15 GB free disk.

```bash
# Build the Docker image (first time only)
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

## Buildbox

Buildbox is a native arm64 Debian VM. Because there's no emulation overhead, it's significantly faster than Docker on Apple Silicon — typically 3–5× faster.

**Prerequisites:** UTM (macOS) or any arm64 Debian host with SSH access. ~15 GB free disk on the VM.

### First-time setup

Create the VM using the bundled cloud-init config:

```bash
bin/buildbox.sh create
```

This provisions the VM with the right dependencies via cloud-init. Set the VM's IP in `.env` or add `buildbox` to `/etc/hosts`:

```bash
echo "192.168.64.X  buildbox" | sudo tee -a /etc/hosts
```

### Running a build

```bash
# Full pipeline: sync code → build → verify → download artifacts
bin/buildbox.sh

# Or run steps individually:
bin/buildbox.sh sync      # push local repo to buildbox
bin/buildbox.sh build     # sync + build
bin/buildbox.sh verify    # run verification checks on artifacts
bin/buildbox.sh fetch     # download artifacts/ to local machine
bin/buildbox.sh ssh       # open an interactive shell
```

The image lands in `artifacts/` on your local machine after `fetch`.

## Verifying a build

`bin/verify.sh` checks the artifacts without needing hardware:

```bash
bin/verify.sh artifacts/
```

It inspects partition layout, boot contents, initramfs structure, rootfs, systemd units, kernel config, and module dependencies. It does not boot the image.

## Common issues

**Buildroot doesn't pick up your source changes** — Buildroot caches package output and won't re-run install steps if it doesn't detect a change. After editing files under `br2-external/package/offlinelab-*/src/`, force a rebuild:

```bash
make offlinelab-<package>-dirclean
```

Then run the build again.

**First build takes very long** — expected. The first run compiles the full toolchain, kernel, and all packages from source. This takes 30–90 minutes depending on your machine. Subsequent builds only rebuild what changed.

**Docker build fails with `exec format error`** — Docker Desktop doesn't have the arm64 emulation layer enabled. Go to Docker Desktop → Settings → Features in development → Enable Rosetta for x86/amd64 emulation, or enable QEMU under experimental features.
