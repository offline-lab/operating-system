# Power — runtime power profile management

**Source:** `framework/library/power.sh`

Runtime power profile management for labctl. Switches the cpufreq governor and USB autosuspend settings on the running system. All functions require the framework to be sourced before this file.

Requires: `config` module, `systemctl` (for `power::set_profile`), root privileges (for `power::apply_profile`).

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## Profiles

| Profile | cpufreq governor | USB autosuspend |
|---|---|---|
| `performance` | `performance` | disabled (`on`, delay `-1`) |
| `balanced` | `schedutil` | 2000 ms (default) |
| `saver` | `powersave` | 500 ms |

The active profile is persisted to `/data/config/power/profile`. On boot, `power-profile.service` reads it and calls `power::apply_profile`. If no profile is stored, `balanced` is used.

## CLI

```
labctl power [get]        # show active profile
labctl power set <name>   # persist and apply a profile
labctl power apply        # re-apply persisted profile (called at boot)
labctl power list         # list available profiles
```

## Functions

### `power::list_profiles`

> Listing available profiles

Prints the three profile names, one per line.

---

### `power::is_valid_profile <name>`

> Validating profile: \<name\>

Returns `0` if `name` is one of `performance`, `balanced`, `saver`. Returns `1` otherwise.

---

### `power::get_profile`

> Reading current profile

Reads the profile from `/data/config/power/profile`. Returns `balanced` if no profile is stored.

---

### `power::apply_profile <name>`

> Applying profile: \<name\>

Writes the cpufreq governor and USB autosuspend settings for the named profile to sysfs. Requires root — intended to be called by `power-profile.service` or as root directly. Fails with return code `1` for an unknown profile name.

Sysfs paths written:
- `$POWER_CPUFREQ_PATH/policy*/scaling_governor`
- `$POWER_USB_PATH/*/power/control`
- `$POWER_USB_PATH/*/power/autosuspend_delay_ms`

Both path variables default to the standard kernel sysfs locations and can be overridden in tests.

---

### `power::set_profile <name>`

> Setting profile: \<name\>

Persists the named profile to `/data/config/power/profile`, then restarts `power-profile.service` to apply it. The service runs as root so no direct sysfs access is required from the caller.

---
