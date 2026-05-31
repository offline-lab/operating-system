# Components

## OS packages

The base OS is built from a set of focused Buildroot packages. Each is self-contained with its own scripts and systemd units.

| Package | Purpose |
|---|---|
| `offlinelab-base` | Data partition setup, fake-hwclock, serial console, boot partition mount |
| `offlinelab-usb-gadget` | USB composite gadget: ACM serial (ttyGS0) + ECM ethernet (usb0) |
| `offlinelab-wifi` | WiFi via wpa_supplicant, credential provisioning |
| `offlinelab-ssh` | Dropbear SSH, key-only auth, host key generation |
| `offlinelab-zram` | Compressed RAM swap |
| `offlinelab-disco` | Service discovery and name resolution (Phase 2) |

See [Packages](packages.md) for details on each package and the provisioning pattern.

## Service model

Services on Offline Lab are packaged as squashfs images and run as systemd portable services. The base OS provides the foundation. Services provide the functionality.

Each service image contains everything it needs. Images are placed on `/data/portable` and attached using systemd's portable service mechanism.

User data stays on `/data`, separate from the service image. Updating a service means replacing its image without losing data.

## Planned services

### Knowledge

Wikipedia and reference content via Kiwix, medical information, programming references (Stack Overflow archives), and offline street maps.

### Communication

Local messaging and real-time chat between users on the network. LoRa and Meshtastic integration for long-range communication between communities.

### Personal tools

Notes and document editing, contact management, personal storage and backups, e-reader library with sync.

### Media

Video and music collections with HTTP and Bluetooth playback, photo gallery.

### Gaming

Retro gaming service optimised for offline usage.

### Infrastructure

DNS for the local domain, DHCP (via travel router or on-device), Debian package mirror for development, and data sync tooling.

## Offline concessions

Services are designed around a "cutoff" moment, after which no new data can be fetched.

Content databases like Wikipedia and maps are frozen at the last sync. Security updates stop arriving. The network compensates with strict firewall rules and known-client policies. Services must work indefinitely without upstream connectivity.
