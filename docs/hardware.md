# Hardware

## Supported devices

The platform targets the **Raspberry Pi Zero 2W** on **arm64**. Support for other hardware is planned but not yet on the roadmap.

The Zero 2W is small, low-power, and capable enough for a small group of users. The goal is a setup that fits in a bag with a stack of powerbanks.

## Storage

Each device boots from a micro SD card. Minimum card size is **8 GB**.

The card is partitioned as follows:

| Partition | Type | Purpose |
|---|---|---|
| `/boot/firmware` | FAT32 | Shared boot partition: kernel, firmware, config |
| Root A | ext4, read-only | Primary root filesystem |
| Root B | ext4, read-only | Secondary root filesystem for A/B updates |
| `/data` | ext4, read-write | User data, service state, writable paths |

The `/data` partition is last on the card and expands to fill the remaining space on first boot.

See [Boot](boot.md) for the full partition layout and boot chain.

## Power

There are no specific watt-hour targets. The principle is to minimize consumption at every level:

- Disable services that aren't actively needed
- No background tasks, cron jobs, or periodic polling
- Clean logs at boot
- Measure and cut unnecessary CPU and memory usage

The system should run as long as possible on a standard USB powerbank.

## Networking

### Travel router

The recommended setup is a low-power travel router providing WiFi between nodes and, when available, upstream internet for syncing data. No specific model is required. Any device that provides WiFi and DHCP works.

### WiFi

Devices connect to the travel router or any configured network. Credentials are loaded from the `/boot/firmware` partition, so WiFi can be configured by mounting the SD card on any computer. DHCP is used for IP assignment.

### Mesh

Batman-adv mesh networking between nodes is a future goal. This could replace the travel router and reduce power consumption by removing a separate device.

### USB

The Zero 2W's USB OTG port supports serial console access and USB networking (gadget mode). Serial is useful for debugging and configuration. USB networking lets a phone or laptop connect directly to the device's services. How to select or combine these modes is under development.
