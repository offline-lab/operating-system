# Configuration

There are three ways to configure the OS:

1. **Build time**: options in `.config` baked into the image
2. **Boot partition provisioning**: files placed in `/boot/firmware/config/` are consumed by the initramfs on next boot and land in `/data/config/`
3. **Runtime**: editing files directly on `/data` (requires SSH or console access)

## Build-time configuration

Copy `config.example` to `.config` in the repo root. Options in `.config` override the Buildroot defconfig at build time.

### Development admin user

```ini
BR2_PACKAGE_OFFLINELAB_ADMIN=y
BR2_PACKAGE_OFFLINELAB_ADMIN_AUTHORIZED_KEY="ssh-ed25519 AAAA... you@host"
```

Bakes an `admin` user (uid 1000) with your SSH key into the read-only rootfs. Convenient for development; do not use in production images.

### Baking WiFi credentials into the boot partition example config

```ini
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_CREATE=y
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_SSID="your-network"
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_PASSWORD_HASH="<hash from wpa_passphrase>"
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_COUNTRY="NL"
```

Writes WiFi credentials into `bootconf.yaml.example` on the boot partition at build time. This is a dev/lab convenience: copy `bootconf.yaml.example` to `bootconf.yaml` before first boot. Use the hash from `wpa_passphrase <ssid> <password>`, not the plaintext password.

**Security note:** Build-time credentials are baked into every image flashed from that build. For per-card configuration, use `bootconf.yaml` on the boot partition instead.

## Boot-partition provisioning

Place files under `/boot/firmware/config/` on the FAT32 boot partition. On the next boot, the initramfs copies the entire `config/` tree into `/data/config/` (overwriting existing files) and then deletes `config/` from the boot partition. All services read exclusively from `/data/config/`.

The primary provisioning file is `bootconf.yaml`. The boot partition contains `bootconf.yaml.example` at build time. To activate:

```sh
# mount boot partition, then:
mkdir -p /mnt/config
cp /mnt/bootconf.yaml.example /mnt/config/bootconf.yaml
# edit /mnt/config/bootconf.yaml
```

The file format covers:
- SSH authorized keys
- WiFi SSID and PSK hash
- Sudoers rules
- sysusers entries (custom users/groups)

`bootconf.service` is idempotent: it tracks what it has already applied and skips re-applying unchanged entries. To force re-provisioning, delete the relevant file from `/data` and reboot.

The boot partition is FAT32 and can be written from any OS. Re-provisioning after first boot (e.g. WiFi credentials changed) works the same way: place updated files in `config/` on the SD card and reboot.

See [Boot partition configuration](bootfs-config.md) for the full layout and `bootconf.yaml` reference.

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

Changes take effect immediately; dropbear re-reads the file on each connection.

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
