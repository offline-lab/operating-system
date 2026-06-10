# Configuration

There are three ways to configure the OS:

1. **Build time** — options in `.config` baked into the image
2. **Boot partition** — `bootconf.yaml` placed on the FAT32 boot partition, applied at every boot by `bootconf`
3. **Runtime** — editing files directly on `/data` (requires SSH or console access)

## Build-time configuration

Copy `config.example` to `.config` in the repo root. Options in `.config` override the Buildroot defconfig at build time.

### Development admin user

```ini
BR2_PACKAGE_OFFLINELAB_ADMIN=y
BR2_PACKAGE_OFFLINELAB_ADMIN_AUTHORIZED_KEY="ssh-ed25519 AAAA... you@host"
```

Bakes an `admin` user (uid 1000) with your SSH key into the read-only rootfs. Convenient for development — do not use in production images.

### Baking WiFi credentials into the boot partition example config

```ini
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_CREATE=y
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_SSID="your-network"
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_PASSWORD_HASH="<hash from wpa_passphrase>"
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_COUNTRY="NL"
```

Writes WiFi credentials into `bootconf.yaml.example` on the boot partition at build time. This is a dev/lab convenience: copy `bootconf.yaml.example` → `bootconf.yaml` before first boot. Use the hash from `wpa_passphrase <ssid> <password>`, not the plaintext password.

**Security note:** Build-time credentials are baked into every image flashed from that build. For per-card configuration, use `bootconf.yaml` on the boot partition instead.

## Boot-partition provisioning (bootconf)

Place a `bootconf.yaml` file on the FAT32 boot partition. `bootconf.service` reads it at every boot and applies the configuration before other services start.

The boot partition contains `bootconf.yaml.example` — copy it to `bootconf.yaml` and fill in your settings. The file format covers:
- SSH authorized keys
- WiFi SSID and PSK hash
- Sudoers rules
- sysusers entries (custom users/groups)

Bootconf is idempotent: it tracks what it has already applied and skips re-applying unchanged entries. To force re-provisioning, delete the relevant file from `/data` and reboot.

The boot partition is FAT32 and can be written from any OS before the card is inserted.

See [Boot partition configuration](bootfs-config.md) for the boot partition layout and full `bootconf.yaml` reference.

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
sudo nano /data/home/admin/.ssh/authorized_keys
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
│   ├── firewall/
│   │   └── rules.d/                # per-app nftables rule fragments
│   ├── system/
│   │   └── machine-id              # stable machine-id across A/B slot switches
│   └── resources.json              # resource baseline (written at boot)
├── home/
│   └── admin/
│       ├── .bashrc
│       └── .ssh/
│           └── authorized_keys     # live SSH public keys
├── apps/                           # systemd portable service images (.raw)
└── extensions/
    ├── sysext/                     # sysext images (bind-mounted to /var/lib/extensions)
    └── confext/                    # confext images (bind-mounted to /etc/extensions)
```

The overlay partition (separate from `/data`) holds the overlayfs upper/work directories and is managed automatically. User data should not be placed there.
