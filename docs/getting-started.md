# Getting Started

Walk through getting MoreOS running on a Raspberry Pi Zero 2W — from building the OS to connecting over SSH.

## What you need

- A Raspberry Pi Zero 2W
- A micro SD card, at least 8 GB
- A USB powerbank or USB-C power supply
- A computer to build the image and write the SD card (macOS or Linux)
- Docker Desktop or a native arm64 build VM

## Step 1 — Build and configure the image

Build the OS image and configure WiFi and SSH credentials. See [Build the OS image](build-image.md) for full instructions covering both Docker and Buildbox paths.

The output is a compressed image file: `artifacts/offlinelab-sdcard-<date>.img.gz`.

## Step 2 — Install MoreOS on the SD card

Write the image to your SD card. See [Install MoreOS](burn-image.md) for the full procedure with troubleshooting.

## Step 3 — Boot

Insert the SD card into the Pi Zero 2W and connect power. The first boot takes slightly longer because the data partition is expanded to fill the card.

## Step 4 — Connect

Find the device's IP address from your router's DHCP lease table, or use the serial console if you have a USB-to-serial adapter. Then:

    ssh app@<ip-address>

Once connected, check the system status with [labctl](labctl.md):

    labctl status

## What's next

- [Hardware](hardware.md) — power and networking setup
- [Packages](packages.md) — how the OS is structured
- [Configuration](configuration.md) — WiFi, SSH, and runtime config
- [Contributing](contributing.md) — if you want to help build
