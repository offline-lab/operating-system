# labctl

labctl is the on-device CLI for managing MoreOS. Connect to your device via SSH and run `labctl status` to see the current system state.

Run `labctl help` for an interactive command browser (uses fzf when available).

## What it manages

### System status

`labctl status` — Shows a health overview: active RAUC slot, AppArmor and dm-verity state, failed systemd units, and disk/memory usage.

### Updates (A/B)

`labctl update` — Installs a RAUC bundle, searching `/mnt` for `.raucb` files if no path is given. The device uses an A/B partition scheme, so updates are applied to the inactive slot.

`labctl rollback` — Reverts to the previously installed slot and offers to reboot.

`labctl reboot` — Reboots the device, optionally into a specific RAUC slot.

### Network

`labctl net` — Manages WiFi connections. Subcommands: `status` (current state and IP), `scan` (available networks), `connect <ssid> <psk>`.

### Configuration

`labctl config` — Reads and writes persistent key/value config stored in `/data/config`. Common keys include `hostname` and `timezone`. Run `config apply` to activate changes.

### Services

`labctl service` — Manages portable services: list, start, stop, enable (start on boot), and disable.

### Logs

`labctl logs` — Queries the systemd journal with filtering by unit, priority, or boot. Supports `--follow` for live output.

### Power

`labctl power` — Manages runtime power profiles (CPU governor + USB autosuspend). Available profiles: `performance`, `balanced` (default), and `saver`.

### Diagnostics

`labctl diagnose` — Collects system diagnostics into a tarball: RAUC slot status, failed units with journals, AppArmor denials, boot logs, WiFi status, and resource usage.

## Getting started

    ssh app@<device-ip>
    labctl status

## Command reference

See the [full command reference](framework/commands.md) for all available commands and options.
