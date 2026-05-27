# Boot partition configuration

The boot partition (`/boot/firmware`, vfat, ~32 MB) is mounted read-only at runtime.
It holds firmware blobs, U-Boot, the kernel squashfs, and a `config/` subdirectory
for user-supplied configuration that is provisioned into `/data` on first boot.

## Boot partition layout

```
/boot/firmware/
├── config/                     # user configuration (see below)
│   ├── authorized_keys         # optional — SSH public keys for the app user
│   └── wpa_supplicant.conf     # optional — WiFi credentials
├── overlays/                   # RPi device tree overlays (firmware package)
├── bcm2710-rpi-zero-2-w.dtb    # device tree blob
├── bootcode.bin                # RPi first-stage bootloader
├── boot.scr                    # U-Boot script
├── cmdline.txt                 # kernel command line
├── config.txt                  # RPi firmware config
├── fixup.dat                   # RPi firmware fixup
├── initramfs.cpio.gz           # initramfs
├── start.elf                   # RPi VideoCore firmware
└── u-boot.bin                  # U-Boot
```

## The config/ subdirectory

Only `config/authorized_keys` and `config/wpa_supplicant.conf` are recognised.
Both are optional — if absent, provisioning skips silently.

Files are picked up by `post-image.sh` during the build and included in the vfat
image only if they exist. They are never baked into the root filesystem.

## Provisioning on first boot

Each file is a one-shot copy into persistent storage under `/data`:

| Boot partition file                     | Destination                              | Service            |
|-----------------------------------------|------------------------------------------|--------------------|
| `config/authorized_keys`               | `/data/home/app/.ssh/authorized_keys`    | `provision-ssh`    |
| `config/wpa_supplicant.conf`           | `/data/config/wifi/wpa_supplicant.conf`  | `provision-wifi`   |

Provisioning is idempotent — if the destination already exists the service exits
without overwriting it. Re-provisioning requires manually removing the file from `/data`.

## Getting config onto the boot partition

### Method 1: build-time (via .config)

Set options in your `.config` overlay (copy `config.example` to `.config`):

```ini
# SSH authorized keys
BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS=y
BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS_CONTENT="ssh-ed25519 AAAA... you@host"

# WiFi credentials
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_CREATE=y
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_SSID="your-ssid"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_PASSWORD="your-password"
BR2_PACKAGE_OFFLINELAB_WIFI_WPA_COUNTRY="NL"
```

The build writes the files to `BINARIES_DIR/config/` and `post-image.sh` includes
them in the vfat image automatically.

### Method 2: manual SD card write

After flashing `sdcard.img`, mount the boot partition (first partition, vfat) and
create the `config/` directory:

```sh
# mount the boot partition
mount /dev/sdX1 /mnt

mkdir -p /mnt/config

# WiFi
cp wpa_supplicant.conf /mnt/config/
chmod 600 /mnt/config/wpa_supplicant.conf

# SSH
cp ~/.ssh/id_ed25519.pub /mnt/config/authorized_keys

umount /mnt
```

The `wpa_supplicant.conf` format for WPA2:

```
ctrl_interface=DIR=/run/wpa_supplicant GROUP=netdev
update_config=1
country=NL

network={
    ssid="your-ssid"
    psk="your-password"
}
```

Use `wpa_passphrase <ssid> <password>` to generate a hashed PSK instead of
storing the password in plain text.

## Security notes

- The boot partition is mounted read-only at runtime (`ro,noatime`).
- `authorized_keys` is copied with mode `600`, owned by `app` (uid 1000).
- `wpa_supplicant.conf` is copied with mode `600`.
- After first boot the boot partition files are no longer needed; the live copies
  are in `/data/config/` and `/data/home/app/.ssh/`.
- If you used the build-time method, the credentials are stored in your buildroot
  `.config` and in the image. Treat both as sensitive.
