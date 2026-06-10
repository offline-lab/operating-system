# Boot configuration (bootconf)

`bootconf` is the boot-time configuration tool for Offline Lab OS. It reads
`/boot/firmware/bootconf.yaml` at every boot and applies the configuration it
describes before other services start.

Source: [github.com/offline-lab/bootconf](https://github.com/offline-lab/bootconf) · Docs: [bootconf.offline-lab.com](https://bootconf.offline-lab.com)

## How it works

1. `bootconf.service` runs at `multi-user.target` before other services.
2. It reads `/boot/firmware/bootconf.yaml` (on the FAT32 boot partition).
3. For each enabled section it applies the configuration to `/data`.
4. `bootconf-sysusers.service` runs immediately after and calls `systemd-sysusers` to create any declared users and groups.

Bootconf is **idempotent**: each section writes a status file under `/data/bootconf/`. If the status file already exists and the configuration hasn't changed, the section is skipped. To force re-provisioning, delete the relevant file from `/data` and reboot.

## Setup

The boot partition contains a `bootconf.yaml.example` file placed there at build time. To activate it:

1. Mount the boot partition (FAT32, accessible from any OS).
2. Copy `bootconf.yaml.example` to `bootconf.yaml`.
3. Edit `bootconf.yaml` with your credentials.
4. Eject the card and boot.

## bootconf.yaml reference

```yaml
bootconf:
  enabled: true
  # Status files written here after each section runs
  directory: /data/bootconf

wifi:
  enabled: false
  directory: /data/config/wifi
  ssid: "your-network"
  # PSK hash from: wpa_passphrase <ssid> <password>
  # Do NOT use the plaintext password here
  password_hash: "abc123..."
  country: NL

ssh:
  enabled: true
  directory: /data/config/ssh
  keytype: ed25519
  generate_host_keys: true
  daemon: dropbear

system:
  enabled: true
  timezone: Europe/Amsterdam
  hostname: offline-lab

services:
  enabled: true
  directory: /data/config/services
  services:
    - name: disco
      enabled: false
      sentinel: true
      default_config:
        copy: true
        source: /etc/disco/config.yaml
        destination: /data/config/disco/config.yaml

sudo:
  enabled: true
  directory: /data/config/sudo

users:
  # Creates users/groups via systemd-sysusers
  enabled: false
  directory: /data/config/users
  users: []

files:
  # Copy files into /data. Existing files get a .new suffix instead of being overwritten.
  enabled: false
  files: []
```

## Sections

### wifi

Writes a `wpa_supplicant.conf` to `/data/config/wifi/` if one does not already exist.

- `ssid`: network SSID
- `password_hash`: PSK hash from `wpa_passphrase <ssid> <password>`, **not** the plaintext password
- `country`: ISO 3166-1 alpha-2 country code (e.g. `NL`, `US`, `GB`)

### ssh

Generates a dropbear host key if absent and writes it to `/data/config/ssh/hostkey`.

SSH authorized keys are not managed by this section. Place them via the `files` section or write them directly to `/data/home/admin/.ssh/authorized_keys`.

### system

Sets the hostname and timezone. Applied once and tracked via a status file.

### services

Copies default config files for named services into `/data/config/<name>/` if they do not already exist. The `sentinel: true` flag means the service is only configured, not started. Bootconf leaves service enablement to systemd.

### sudo

Writes sudoers drop-in files to `/data/config/sudo/` (included from `/etc/sudoers.d/`).

### users

Writes sysusers config fragments that `bootconf-sysusers.service` passes to `systemd-sysusers`. Use this to create per-app users before services start.

### files

Copies arbitrary files into place. If the destination already exists, the source is copied as `<destination>.new` instead of overwriting.

## Build-time WiFi convenience

For development builds, bake WiFi credentials into `bootconf.yaml.example` at build time:

```ini
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_CREATE=y
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_SSID="your-network"
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_PASSWORD_HASH="<hash>"
BR2_PACKAGE_OFFLINELAB_BOOTCONF_WIFI_COUNTRY="NL"
```

This writes the values into the example file placed on the boot partition. Copy it to `bootconf.yaml` to activate. Do not use this on production images; the hash is visible to anyone who can read the boot partition.

## Systemd units

| Unit | When | What |
|---|---|---|
| `bootconf.service` | `multi-user.target` | Reads `bootconf.yaml` and applies all enabled sections |
| `bootconf-sysusers.service` | After `bootconf.service` | Runs `systemd-sysusers` to create declared users |
