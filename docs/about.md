# About

## Purpose

Offline Lab is an open-source platform for running applications on low-power devices without internet. We build software for situations where connectivity is unreliable or unavailable — travel, remote areas, temporary setups — and existing tools stop working when the network drops.

MoreOS currently targets the Raspberry Pi Zero 2W and QEMU, with support for additional hardware planned.

## Use cases

Offline Lab serves people who need computing tools but can't depend on internet access:

- **Travelers** on long trips, cruises, or remote itineraries who want their own services — file sharing, media, communication — without roaming or satellite costs.
- **Off-grid communities** in rural or remote areas where internet is slow, expensive, or absent. A few Raspberry Pis provide local services for the whole community.
- **Small groups** that want to share services over a local network without routing anything through the cloud. A travel router and a couple of nodes are enough to get started.

In all cases, the platform works fully offline. When internet is available, it syncs data and pulls updates. When it isn't, nothing breaks.

## What it does

MoreOS is a minimal, read-only [operating system](operating-system.md) built with Buildroot. It boots from an SD card and keeps user data on a separate writable partition. System updates use A/B root partitions: write the new image to the inactive slot, reboot, and the system switches over.

Applications ship as **portable services** — squashfs images containing everything they need, managed as systemd portable services. No package managers, no dependency resolution. Drop the image on the device and start it. See the [service model](components.md) for details.

**Disco** handles service discovery and name resolution on the local network. Nodes find each other without manual configuration, whether connected over a travel router, WiFi mesh, or direct WiFi. See the [Discovery](discovery/) documentation for the protocol and CLI.

The **framework** is a Bash utility library and [`labctl`](labctl.md) CLI installed on every device. It provides logging, configuration management, WiFi setup, health checks, update operations, and other on-device tooling.

See [Terminology](terminology.md) for definitions of terms used throughout the docs.

Nodes connect over a travel router or WiFi mesh. Each node also works standalone, powered by a USB power bank.

## Design principles

**[Offline](offline.md)-first, not offline-only.** When internet is available, the platform syncs data and pulls updates. When it isn't, everything keeps working. The system never waits for a network that isn't there.

**Low power above all.** Every design decision optimizes for battery life. No background polling, no unnecessary logging, no idle services. If something costs CPU or memory without directly serving users, it gets cut.

**Simple over clever.** SQLite over PostgreSQL. Bind mounts over complex storage layers. Systemd over custom init scripts. Boring technology, no premature abstraction.

**Portable packages.** Each application ships as a self-contained squashfs image. No package managers, no dependency resolution at runtime. Drop the image, start the service.

**Community-oriented.** The platform serves people who need daily computing tools without reliable internet: communication, knowledge sharing, entertainment, and personal data management.

## Project ecosystem

| Repository | Description |
|---|---|
| [builder](https://github.com/offline-lab/builder) | MoreOS image builder (Buildroot), framework, labctl, and on-device tooling |
| [disco](https://github.com/offline-lab/disco) | Service discovery and name resolution for offline networks |
| packages | Portable systemd service packages (planned) |
| sync | Data synchronization tools (planned) |

## License

Offline Lab is released under [AGPL v3](https://www.gnu.org/licenses/agpl-3.0.en.html).

## Who builds this

Offline Lab is an open-source community project. Contributions are welcome — see the [contributing guide](contributing.md) to get started.
