# Packages

The OS is organised as a Buildroot external tree (`br2-external`). Functionality is split into focused packages under `br2-external/package/offlinelab-*/`. Each package is self-contained: it installs its own binaries, scripts, and systemd units.

## Package overview

| Package | Purpose |
|---|---|
| `offlinelab-base` | Core OS setup: boot partition mount, data partition expansion, sysext/confext bind mounts, power profile, serial console, `/etc/issue` |
| `offlinelab-bootconf` | Boot-time configuration tool: reads `/boot/firmware/bootconf.yaml` and applies SSH keys, WiFi config, sudoers, and sysusers before other services start |
| `offlinelab-framework` | Bash utility library and boxctl CLI installed at `/usr/lib/framework/` |
| `offlinelab-firewall` | nftables-based firewall: static rules on the read-only rootfs, per-app rule fragments under `/data/config/firewall/rules.d/` |
| `offlinelab-usb-gadget` | USB composite gadget: ACM serial (ttyGS0) + ECM ethernet (usb0, 10.55.0.1/24) |
| `offlinelab-wifi` | WiFi via wpa_supplicant |
| `offlinelab-ssh` | Dropbear SSH server, key-only auth |
| `offlinelab-zram` | Compressed RAM swap for low-memory operation |
| `offlinelab-portable` | systemd portable service support: `/data/apps` symlink, sysext/confext bind mounts, `systemd-portabled`, module loading |
| `offlinelab-resources` | Resource baseline: samples RAM/CPU/storage at boot and writes `/data/config/resources.json` |
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

First-boot configuration is handled by `offlinelab-bootconf`. At every boot, `bootconf.service` reads `/boot/firmware/bootconf.yaml` and applies the configuration it describes:

- SSH authorized keys: `/data/home/admin/.ssh/authorized_keys`
- WiFi credentials: `/data/config/wifi/wpa_supplicant.conf`
- Sudo rules, sysusers entries, home directory setup

Bootconf is idempotent: if a target file already exists on `/data`, it is left unchanged. To re-provision a setting, delete the live copy from `/data` and reboot.

To configure a new device, copy `bootconf.yaml.example` from the boot partition (written there at build time) to `bootconf.yaml` and fill in your credentials. The boot partition is FAT32 and can be written from any OS.

## offlinelab-base

**Systemd units:**
- `boot-firmware.mount`: mounts `/boot/firmware` read-only after `dev-mmcblk0p1.device` appears
- `expand-data.service`: first-boot data partition resize and format; creates `/data` directory structure
- `var-lib-extensions.mount`, `etc-extensions.mount`: bind-mount `/data/extensions/sysext/` and `/data/extensions/confext/` at sysinit
- `systemd-sysext.service`, `systemd-confext.service`: enabled at sysinit.target
- `power-profile.service`: applies CPU governor and power settings at boot
- `boxctl-shutdown.service`: runs boxctl shutdown hook on shutdown

**Other:**
- `serial-getty@ttyS0.service`: enabled for GPIO UART console (115200 baud)
- `getty@tty1.service`: enabled for HDMI+keyboard console
- `/etc/issue`: shows IP addresses for wlan0 and usb0 at the login prompt

## offlinelab-bootconf

Boot-time configuration tool that reads `/boot/firmware/bootconf.yaml` and applies SSH keys, WiFi credentials, sudoers rules, and sysusers entries before `multi-user.target`.

**Systemd units:**
- `bootconf.service`: reads and applies `bootconf.yaml` at boot
- `bootconf-sysusers.service`: creates users/groups declared in the config

**Build options:**
- `BR2_PACKAGE_OFFLINELAB_BOOTCONF_VERSION`: git tag to build (e.g. `v1.0.0`)
- `BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_CREATE=y`: bake WiFi credentials into `bootconf.yaml.example` on the boot partition at build time (dev/lab convenience only)

Source: `github.com/offline-lab/bootconf`

## offlinelab-firewall

nftables-based firewall. Static rules covering SSH, ICMP, and established connections are loaded from the read-only rootfs at `/etc/firewall/rules.fw`. Per-app dynamic rules are persisted as fragments under `/data/config/firewall/rules.d/<app>.rules` and replayed on boot.

**Systemd units:**
- `firewall.service`: loads rules at boot via `firewall-init`

**Other:**
- `firewall-init`: load rules from rootfs and apply fragments from `/data`
- `firewall-restore`: re-apply rules without reboot (called by fw.sh on rule changes)

Runtime management via the `fw.sh` framework module and `boxctl firewall`.

## offlinelab-resources

Samples RAM, CPU, and storage over ~5 seconds at boot and writes a resource baseline to `/data/config/resources.json`. The `resources.sh` framework module reads this file for resource-aware operations at runtime.

**Systemd units:**
- `offlinelab-resources.service`: runs after `sysinit.target`, before `multi-user.target`

## offlinelab-usb-gadget

Configures the Pi's USB OTG port as a composite gadget providing two functions simultaneously:

- **ACM serial** (`ttyGS0`): `serial-getty@ttyGS0` provides a login shell
- **ECM ethernet** (`usb0`): `usb0.network` assigns `10.55.0.1/24` with DHCPServer

The gadget setup script detects whether a USB keyboard or other USB host device is already connected. If so, it stays in USB host mode and skips gadget setup. USB host (keyboard) and gadget mode are mutually exclusive on the Zero 2W OTG port.

## offlinelab-wifi

**Systemd units:**
- `wifi-setup.service`: starts wpa_supplicant after wlan0 appears (`BindsTo=sys-subsystem-net-devices-wlan0.device`)
- `show-ip.service`: updates `/etc/issue` with the current IP addresses after network is up

**Notes:**
- WiFi credentials are provisioned by `offlinelab-bootconf` via `bootconf.yaml`.
- `wpa_cli` is available for runtime WiFi management.
- `wlan0.network` uses DHCP.
- A kernel module workaround (`02w-wifi-fix.conf`) addresses a timing issue with the brcmfmac driver on the Zero 2W.

## offlinelab-ssh

**Systemd units:**
- `dropbear.service`: starts dropbear SSH server

**Notes:**
- Password authentication is disabled. Key-only access only.
- SSH authorized keys are provisioned by `offlinelab-bootconf` via `bootconf.yaml`.
- Host keys are generated by bootconf on first boot and persist at `/data/config/ssh/hostkey`.
- Connect as user `admin` (uid 1000, passwordless sudo).

## offlinelab-zram

Configures a zram block device as compressed swap:

- Uses LZ4 compression (fast, CPU-efficient)
- Size: half of physical RAM (256MB on Zero 2W)
- Loaded via `modules-load.d` (`CONFIG_ZRAM=m` in kernel)

## offlinelab-disco

Provides:
- `disco-daemon`: UDP broadcast discovery and hostname resolution
- `libnss_disco.so.2`: glibc NSS module for native hostname resolution
- `disco` CLI
- `disco-gps-broadcaster`: time synchronization from GPS sources (not enabled by default)

**Systemd units:**
- `disco-daemon.service`: enabled at multi-user.target

See [Disco](disco.md) for the full protocol and design.

## Adding a package

1. Create `br2-external/package/offlinelab-<name>/` with `Config.in` and `offlinelab-<name>.mk`.
2. Add `source "package/offlinelab-<name>/Config.in"` to `br2-external/Config.in`.
3. Add the package to the defconfig (`BR2_PACKAGE_OFFLINELAB_<NAME>=y`).
4. Place source files in `src/` and install them from the `.mk` file.

After editing source files under `src/`, run `make offlinelab-<name>-dirclean` before rebuilding. Buildroot won't re-run install steps otherwise.
