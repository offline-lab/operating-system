# Getting Started

This tutorial walks you through getting MoreOS running on a Raspberry Pi Zero 2W — from building the image to logging in over SSH.

## What you need

- A Raspberry Pi Zero 2W
- A micro SD card, at least 8 GB
- A USB powerbank or USB-C power supply
- A computer to build the image and write the SD card (macOS or Linux)
- Either Docker or a native arm64 build VM (Buildbox) — see below

## Step 1 — Build the image

You need to build the OS image before you can flash it. There are two ways to do this.

**Docker** is the easiest starting point on macOS. It's slower than Buildbox because it runs arm64 in emulation, but it works without any extra setup beyond Docker Desktop.

**Buildbox** is a native arm64 Debian VM. It's significantly faster and is the recommended path for regular development. It requires a bit more upfront setup.

See [Build the image](build-image.md) for both paths in full detail.

The output is a compressed image file in `artifacts/`: `offlinelab-sdcard-<date>.img.gz`.

## Step 2 — Configure WiFi and SSH

Before building, set your WiFi credentials and SSH key in `.config`:

```ini
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_SSID="your-network"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_PASSWORD="your-password"
BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS_CONTENT="ssh-ed25519 AAAA... you@host"
```

These are baked into the image at build time. See [Configuration](configuration.md) for all options, and [Boot partition config](bootfs-config.md) for the alternative that doesn't require a rebuild.

## Step 3 — Write the image to SD card

See [Burn image to SD card](burn-image.md) for the full procedure. The short version:

```bash
gunzip -k artifacts/offlinelab-sdcard-*.img.gz
sudo dd if=artifacts/offlinelab-sdcard-*.img of=/dev/diskN bs=4M status=progress
```

Replace `/dev/diskN` with the SD card device. On macOS, `diskutil list` shows all disks.

## Step 4 — Boot

Insert the SD card into the Pi Zero 2W, connect power, and wait about 30 seconds. The first boot expands the data partition to fill the remaining card space, which takes a moment.

## Step 5 — Connect

Find the device's IP address from your router's DHCP lease table, or check the serial console if you have a USB-to-serial adapter. Then:

```bash
ssh root@<ip-address>
```

Once connected, `labctl status` shows the system state and any running services.

## What's next

- Read the [Hardware](hardware.md) page for power and networking setup
- Read [Components](components.md) to understand how services are loaded
- Follow [Contributing](contributing.md) if you want to build and run your own services
