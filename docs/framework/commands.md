# boxctl — Command Reference

`boxctl` is the device management CLI installed on the Offline Lab OS.
Run `boxctl help` or `boxctl <command> --help` for interactive help.

---

## `boxctl config`

```
Usage: boxctl config <subcommand> [args]

Subcommands:
  get <key>           Read a config value
  set <key> <value>   Write a config value
  list                List all config keys
  apply               Apply hostname and timezone from config

Keys (common):
  hostname            Device hostname
  timezone            TZ name (e.g. Europe/Amsterdam)
```

## `boxctl diagnose`

```
Usage: boxctl diagnose [--output <dir>]

Collect diagnostics and write a tarball to /tmp (or <dir>).

Collects:
  - RAUC slot status
  - Failed systemd units + their journals
  - AppArmor denials (dmesg)
  - Last boot log
  - Current boot log
  - WiFi status
  - Disk and memory usage

Options:
  --output <dir>   Write tarball to this directory (default: /tmp)
```

## `boxctl logs`

```
Usage: boxctl logs [options]

Options:
  -u, --unit <unit>     Filter by systemd unit
  -p, --priority <p>    Min priority: emerg|alert|crit|err|warning|notice|info|debug
  -n, --lines <n>       Number of lines (default: 50)
  -f, --follow          Follow live output
  --boot                Show current boot only
```

## `boxctl net`

```
Usage: boxctl net <subcommand> [args]

Subcommands:
  status                Show current WiFi state and IP
  scan                  Scan for available networks
  connect <ssid> <psk>  Connect to a WiFi network
```

## `boxctl power`

```
Usage: boxctl power [<subcommand>]

Manage runtime power profile (cpufreq governor + USB autosuspend).

Subcommands:
  get           Show the active profile (default)
  set <name>    Persist and apply a profile
  apply         Re-apply the persisted profile — called at boot by power-profile.service
  list          List available profiles

Profiles:
  performance   CPU governor: performance, USB autosuspend: disabled
  balanced      CPU governor: schedutil,   USB autosuspend: 2000ms  (default)
  saver         CPU governor: powersave,   USB autosuspend: 500ms
```

## `boxctl reboot`

```
Usage: boxctl reboot [<slot>]

Reboot the device, optionally into a specific RAUC slot.
If no slot is given, performs a normal reboot.

Arguments:
  <slot>   RAUC slot name (e.g. rootfs.0, rootfs.1)
```

## `boxctl rollback`

```
Usage: boxctl rollback

Roll back to the previously installed RAUC slot.

Finds the inactive rootfs slot, marks it as the boot target, and offers
to reboot. The current slot is not modified — you can roll forward again
by running: boxctl update
```

## `boxctl screen`

```
Usage: boxctl screen <subcommand> [args]

Manage HDMI display configuration. Settings are stored in /data/config and
written to /boot/firmware/config.txt on apply. A reboot is required for
changes to take effect.

Subcommands:
  status                     Show stored screen configuration
  rotate <degrees>           Set display rotation: 0, 90, 180, 270
  resolution <group> <mode>  Set HDMI resolution (hdmi_group and hdmi_mode)
  apply                      Write stored settings to /boot/firmware/config.txt

Common HDMI groups and modes:
  Group 1 (CEA/TV):  mode 4 = 720p60,  mode 16 = 1080p60
  Group 2 (DMT/PC):  mode 35 = 1024x768@60, mode 82 = 1920x1080@60
```

## `boxctl service`

```
Usage: boxctl service <subcommand> [service]

Subcommands:
  list                List attached portable services and their state
  start <service>     Start a portable service
  stop <service>      Stop a portable service
  enable <service>    Enable a portable service (start on boot)
  disable <service>   Disable a portable service
```

## `boxctl status`

```
Usage: boxctl status

Show system health: RAUC slot info, AppArmor, dm-verity, failed units,
disk and memory usage.
```

## `boxctl update`

```
Usage: boxctl update [<bundle>]

Apply a RAUC bundle. If no path is given, searches /mnt for *.raucb files.
Prompts for confirmation before installing.

Arguments:
  <bundle>   Path to a .raucb file (optional — scans /mnt if omitted)
```
