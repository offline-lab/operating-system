# labctl — Command Reference

`labctl` is the device management CLI installed on the Offline Lab OS.
Run `labctl help` or `labctl <command> --help` for interactive help.

---

## `labctl config`

```
Usage: labctl config <subcommand> [args]

Subcommands:
  get <key>           Read a config value
  set <key> <value>   Write a config value
  list                List all config keys
  apply               Apply hostname and timezone from config

Keys (common):
  hostname            Device hostname
  timezone            TZ name (e.g. Europe/Amsterdam)
```

## `labctl diagnose`

```
Usage: labctl diagnose [--output <dir>]

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

## `labctl logs`

```
Usage: labctl logs [options]

Options:
  -u, --unit <unit>     Filter by systemd unit
  -p, --priority <p>    Min priority: emerg|alert|crit|err|warning|notice|info|debug
  -n, --lines <n>       Number of lines (default: 50)
  -f, --follow          Follow live output
  --boot                Show current boot only
```

## `labctl net`

```
Usage: labctl net <subcommand> [args]

Subcommands:
  status                Show current WiFi state and IP
  scan                  Scan for available networks
  connect <ssid> <psk>  Connect to a WiFi network
```

## `labctl power`

```
Usage: labctl power [<subcommand>]

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

## `labctl reboot`

```
Usage: labctl reboot [<slot>]

Reboot the device, optionally into a specific RAUC slot.
If no slot is given, performs a normal reboot.

Arguments:
  <slot>   RAUC slot name (e.g. rootfs.0, rootfs.1)
```

## `labctl rollback`

```
Usage: labctl rollback

Roll back to the previously installed RAUC slot.

Finds the inactive rootfs slot, marks it as the boot target, and offers
to reboot. The current slot is not modified — you can roll forward again
by running: labctl update
```

## `labctl service`

```
Usage: labctl service <subcommand> [service]

Subcommands:
  list                List attached portable services and their state
  start <service>     Start a portable service
  stop <service>      Stop a portable service
  enable <service>    Enable a portable service (start on boot)
  disable <service>   Disable a portable service
```

## `labctl status`

```
Usage: labctl status

Show system health: RAUC slot info, AppArmor, dm-verity, failed units,
disk and memory usage.
```

## `labctl update`

```
Usage: labctl update [<bundle>]

Apply a RAUC bundle. If no path is given, searches /mnt for *.raucb files.
Prompts for confirmation before installing.

Arguments:
  <bundle>   Path to a .raucb file (optional — scans /mnt if omitted)
```
