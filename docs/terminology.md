# Terminology

Quick reference for terms used across the documentation.

| Term | Meaning |
|---|---|
| **MoreOS** | The offline-first operating system built with Buildroot |
| **Package** | A `.olab` archive containing a squashfs image, metadata, and signature — the distributable unit |
| **Service** | A running instance of an installed package on a device |
| **Framework** | The Bash utility library and labctl CLI bundled with MoreOS |
| **Node** | A single device (e.g. Raspberry Pi Zero 2W) running MoreOS |
| **Disco** | The service discovery and name resolution daemon |
| **Slot** | One of two root filesystem partitions (A/B) used for atomic updates |
| **Boot partition** | The FAT32 partition holding firmware, U-Boot, kernel, and user config |
| **Overlay partition** | Holds per-slot overlayfs upper/work directories |
| **/data** | The persistent read-write partition for user data and package state |
| **labctl** | On-device CLI for managing MoreOS (status, updates, network, diagnostics) |
| **pkgctl** | Build and publish toolchain for packages (planned) |
| **appctl** | On-device CLI for installing and managing packages (planned) |
