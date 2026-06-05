# Packages

The OS is organised as a Buildroot external tree (`br2-external`). Functionality is split into focused packages under `br2-external/package/offlinelab-*/`. Each package is self-contained: it installs its own binaries, scripts, and systemd units.

## Package overview

| Package | Purpose |
|---|---|
| `offlinelab-base` | Core OS setup: boot partition mount, data partition expansion, fake-hwclock, serial console, /etc/issue |
| `offlinelab-framework` | Bash utility library and boxctl CLI installed at `/usr/lib/framework/` |
| `offlinelab-usb-gadget` | USB composite gadget: ACM serial (ttyGS0) + ECM ethernet (usb0, 10.55.0.1/24) |
| `offlinelab-wifi` | WiFi via wpa_supplicant, credential provisioning from boot partition |
| `offlinelab-ssh` | Dropbear SSH, key-only auth, host key generation and key provisioning from boot partition |
| `offlinelab-zram` | Compressed RAM swap for low-memory operation |
| `offlinelab-portable` | systemd portable service support: `/data/portable` mount, `systemd-portabled`, module loading |
| `offlinelab-update` | RAUC A/B OTA updates and USB update via udev (`usb-update@.service`, `rauc-mark-good.service`) |
| `offlinelab-disco` | Service discovery, NSS name resolution, time sync |

## Package structure

Each package follows a standard layout:

```
offlinelab-<name>/
├── Config.in              # Buildroot Kconfig options
├── offlinelab-<name>.mk   # build rules and install steps
└── src/
    ├── config/            # scripts and config files
    └── systemd/
        ├── service/       # .service unit files
        ├── mount/         # .mount unit files
        └── network/       # .network files (systemd-networkd)
```

The `.mk` file installs everything from `src/` into the target rootfs and enables systemd units via symlinks.

## Provisioning pattern

Several packages implement a common pattern for first-boot configuration:

1. A `provision-<x>.service` unit runs early in the boot sequence.
2. It checks whether a config file already exists in `/data`. If it does, it exits immediately (idempotent).
3. If not, it copies from the boot partition (`/boot/firmware/config/`) to `/data`.

```
/boot/firmware/config/wpa_supplicant.conf  →  /data/config/wifi/wpa_supplicant.conf
/boot/firmware/config/authorized_keys      →  /data/home/app/.ssh/authorized_keys
```

The live copy in `/data` is authoritative. To re-provision, delete the live copy and reboot.

This pattern means the boot partition is never written to at runtime. Config files can be placed there before the first boot using any computer that can mount FAT32.

## offlinelab-base

**Systemd units:**
- `boot-firmware.mount` — mounts `/boot/firmware` read-only after `dev-mmcblk0p1.device` appears
- `expand-data.service` — first-boot data partition resize and format; creates `/data` directory structure
- `fake-hwclock.service` — restores last-known time from `/data/config/fake-hwclock.data` at boot; saves current time on shutdown

**Other:**
- `serial-getty@ttyS0.service` — enabled for GPIO UART console (115200 baud)
- `getty@tty1.service` — enabled for HDMI+keyboard console
- `/etc/issue` — shows IP addresses for wlan0 and usb0 at the login prompt

## offlinelab-usb-gadget

Configures the Pi's USB OTG port as a composite gadget providing two functions simultaneously:

- **ACM serial** (`ttyGS0`) — `serial-getty@ttyGS0` provides a login shell
- **ECM ethernet** (`usb0`) — `usb0.network` assigns `10.55.0.1/24` with DHCPServer

The gadget setup script detects whether a USB keyboard or other USB host device is already connected. If so, it stays in USB host mode and skips gadget setup. USB host (keyboard) and gadget mode are mutually exclusive on the Zero 2W OTG port.

## offlinelab-wifi

**Systemd units:**
- `provision-wifi.service` — copies `wpa_supplicant.conf` from boot partition on first boot
- `wifi-setup.service` — starts wpa_supplicant after wlan0 appears (`BindsTo=sys-subsystem-net-devices-wlan0.device`)

**Notes:**
- `wpa_cli` is available for runtime WiFi management.
- `wlan0.network` uses DHCP.
- A kernel module workaround (`02w-wifi-fix.conf`) addresses a timing issue with the brcmfmac driver on the Zero 2W.

## offlinelab-ssh

**Systemd units:**
- `provision-ssh.service` — generates host keys if absent; copies `authorized_keys` from boot partition
- `dropbear.service` — `Requires=provision-ssh.service` (hard dependency; dropbear won't start without host keys)

**Notes:**
- Password authentication is disabled. Key-only access only.
- Host keys persist at `/data/config/ssh/dropbear/`.
- Connect as user `app` (uid 1000, passwordless sudo).

## offlinelab-zram

Configures a zram block device as compressed swap:

- Uses LZ4 compression (fast, CPU-efficient)
- Size: half of physical RAM (256MB on Zero 2W)
- Loaded via `modules-load.d` (`CONFIG_ZRAM=m` in kernel)

## offlinelab-disco

Provides:
- `disco-daemon` — UDP broadcast discovery and hostname resolution
- `libnss_disco.so.2` — glibc NSS module for native hostname resolution
- `disco` CLI
- Time synchronization from GPS sources

See [Disco](disco.md) for the full protocol and design.

## Adding a package

1. Create `br2-external/package/offlinelab-<name>/` with `Config.in` and `offlinelab-<name>.mk`.
2. Add `source "package/offlinelab-<name>/Config.in"` to `br2-external/Config.in`.
3. Add the package to the defconfig (`BR2_PACKAGE_OFFLINELAB_<NAME>=y`).
4. Place source files in `src/` and install them from the `.mk` file.

After editing source files under `src/`, run `make offlinelab-<name>-dirclean` before rebuilding — Buildroot won't re-run install steps otherwise.
