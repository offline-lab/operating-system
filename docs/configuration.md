# Configuration

There are three ways to configure the OS:

1. **Build time** — options in `.config` baked into the image
2. **Pre-first-boot** — files placed on the boot partition before the first boot
3. **Runtime** — editing files directly on `/data` (requires SSH or console access)

## Build-time configuration

Copy `config.example` to `.config` in the repo root. Options in `.config` override the Buildroot defconfig at build time.

### WiFi

```ini
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_CREATE=y
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_SSID="your-network"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_PASSWORD="your-password"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_COUNTRY="NL"
```

Generates a `wpa_supplicant.conf` and embeds it in the boot partition image. Country code defaults to `"00"` (worldwide) if not set.

### SSH authorized keys

```ini
BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS=y
BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS_CONTENT="ssh-ed25519 AAAA... you@host"
```

Embeds the key in the boot partition image. Multiple keys: separate them with `\n` in the value.

**Security note:** Build-time credentials are baked into the image. Every SD card flashed from that image will have the same credentials. Use build-time options for development images; use boot-partition provisioning for individual cards.

## Boot-partition provisioning

Place config files in the `config/` subdirectory of the boot partition (FAT32, accessible from any OS):

```
/boot/firmware/config/
├── wpa_supplicant.conf     # WiFi credentials
└── authorized_keys         # SSH public keys for the app user
```

On first boot, provisioning services copy these files to `/data`:

| Source | Destination | Service |
|---|---|---|
| `config/wpa_supplicant.conf` | `/data/config/wifi/wpa_supplicant.conf` | `provision-wifi` |
| `config/authorized_keys` | `/data/home/app/.ssh/authorized_keys` | `provision-ssh` |

Provisioning is **idempotent**: if the destination already exists, the service exits without overwriting it. To re-provision, delete the file from `/data` and reboot.

See [Boot partition configuration](bootfs-config.md) for the full reference: boot partition layout, config file formats, provisioning details, and the manual SD card method.

## Runtime configuration

After first boot, live config lives under `/data`. Changes here are persistent across reboots.

### WiFi

```bash
# Edit credentials
sudo nano /data/config/wifi/wpa_supplicant.conf

# Apply without rebooting
wpa_cli -i wlan0 reconfigure
```

### SSH authorized keys

```bash
# Edit or replace authorized keys
sudo nano /data/home/app/.ssh/authorized_keys
```

Changes take effect immediately — dropbear re-reads the file on each connection.

## /data layout

```
/data/
├── config/
│   ├── wifi/
│   │   └── wpa_supplicant.conf     # live WiFi credentials
│   ├── ssh/
│   │   └── dropbear/               # dropbear host keys (persist across reboots)
│   └── fake-hwclock.data           # last-known time (updated on shutdown)
├── home/
│   └── app/
│       ├── .bashrc
│       └── .ssh/
│           └── authorized_keys     # live SSH public keys
└── portable/                       # systemd portable service images
```

The overlay partition (separate from `/data`) holds the overlayfs upper/work directories and is managed automatically. User data should not be placed there.
