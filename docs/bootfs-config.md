# Boot partition configuration

The boot partition (`/boot/firmware`, FAT32, ~32 MB) is mounted read-only at runtime.
It holds firmware blobs, U-Boot, the kernel squashfs, and a `bootconf.yaml` file that
configures the device on every boot.

## Boot partition layout

```
/boot/firmware/
├── bootconf.yaml               # active configuration (copy from bootconf.yaml.example)
├── bootconf.yaml.example       # template written by the build
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

## bootconf.yaml

`bootconf` reads `/boot/firmware/bootconf.yaml` at every boot and applies the
configuration it describes to `/data`. If a target file already exists, it is not
overwritten. See [Boot configuration (bootconf)](bootconf.md) for the full YAML reference.

To activate configuration on a new card:
1. Mount the boot partition (FAT32, readable from any OS).
2. Copy `bootconf.yaml.example` to `bootconf.yaml`.
3. Edit the file with your credentials (WiFi PSK hash, SSH keys, etc.).
4. Eject and boot.

## Getting config onto the boot partition

### Method 1: build-time (via .config)

Set options in your `.config` overlay (copy `config.example` to `.config`):

```ini
# Bake WiFi credentials into bootconf.yaml.example at build time
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_CREATE=y
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_SSID="your-ssid"
# PSK hash from: wpa_passphrase <ssid> <password>
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_PASSWORD_HASH="abc123..."
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_COUNTRY="NL"
```

### Method 2: manual SD card write

After flashing the image, mount the boot partition (first partition, FAT32) and
copy `bootconf.yaml.example` to `bootconf.yaml`, then edit it:

```sh
mount /dev/sdX1 /mnt
cp /mnt/bootconf.yaml.example /mnt/bootconf.yaml
# edit /mnt/bootconf.yaml — set wifi.ssid, wifi.password_hash, etc.
umount /mnt
```

The boot partition can be mounted and edited from macOS, Windows, or Linux without
any special tools.

## Security notes

- The boot partition is mounted read-only at runtime (`ro,noatime`).
- `bootconf.yaml` is world-readable on the FAT32 partition. Store only the WiFi PSK
  hash (from `wpa_passphrase`), never the plaintext password.
- SSH authorized keys in `bootconf.yaml` are written to `/data/home/admin/.ssh/` with
  mode `600`, owned by `admin` (uid 1000).
- After first boot the live copies in `/data` are authoritative; the boot partition
  file is re-read on every boot but only applies changes that haven't already been applied.
- If you used the build-time WiFi option, the hash is stored in your `.config` and
  baked into the boot partition image. Treat both as sensitive.
