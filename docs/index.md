# Offline Lab

A battery-powered platform for life without internet.

## What is Offline Lab?

Offline Lab is an open-source platform for running apps on low-power devices without internet. We are the opposite of a data center: just enough compute to serve a family or a small community.

The platform has two parts: a minimal read-only operating system (working name: **MinOS**) and a set of services packaged as portable images. Everything runs on battery power, stores data on SD cards, and works without any network connection.

## Use cases

Offline Lab is for people who need computing tools but don't have reliable internet. Travelers on cruises or long trips. Communities in remote or off-grid locations. Small groups that want to share services over a local network.

## How it works

A Raspberry Pi Zero 2W boots a read-only OS from an SD card. Services run as systemd portable services from squashfs images. User data lives on a separate writable partition. Updates use A/B root partitions: write the new image to the inactive slot and reboot.

Nodes connect over a travel router or WiFi mesh. Each node also works standalone, powered by a USB powerbank.

## Project ecosystem

| Repository | Description |
|---|---|
| [website](https://github.com/offline-lab/website) | Documentation and project site |
| [builder](https://github.com/offline-lab/builder) | Buildroot-based OS image builder |
| [disco](https://github.com/offline-lab/disco) | Service discovery and name resolution for offline networks |
| services | Portable systemd service images (Phase 3, planned) |
| sync | Data synchronization tools (planned) |

## Documentation

**Platform**
- [About](about.md) - purpose and philosophy
- [Hardware](hardware.md) - devices, storage, power, networking
- [Offline](offline.md) - offline design decisions
- [Roadmap](roadmap.md) - development phases

**Operating system**
- [Operating System](operating-system.md) - MinOS design principles
- [Boot](boot.md) - boot chain, partition layout, A/B mechanics
- [Packages](packages.md) - OS packages and the provisioning pattern
- [Configuration](configuration.md) - WiFi, SSH, and runtime config reference
- [Components](components.md) - portable service model and planned services

**Infrastructure**
- [Disco](disco.md) - service discovery and name resolution

**Framework**
- [Framework](framework/index.md) - bash library and labctl CLI reference
- [Commands](framework/commands.md) - labctl command reference

**Contributing**
- [Building](builder.md) - how to build the OS image
- [Development](development.md) - repo structure, gotchas, adding packages
- [Contributing](contributing.md) - how to get involved

## License

Offline Lab is licensed under [AGPL v3](https://www.gnu.org/licenses/agpl-3.0.en.html). You can use, modify, and distribute the software, but modifications, including running it as a service, must be released under the same license.
