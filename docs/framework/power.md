# power

**Source:** `framework/library/power.sh`

Runtime power profile management for boxctl. All functions require the framework to be sourced before this file. Requires: config module, systemctl (for set_profile), root (for apply_profile)

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

### `power::list_profiles`

> Listing available profiles

---

### `power::is_valid_profile`

> Validating profile: <value>

**Arguments:** exactly 1 argument(s)

---

### `power::get_profile`

> Reading current profile

---

### `power::_write_sysfs`

> <value> <- <value>

**Arguments:** exactly 2 argument(s)

---

### `power::_set_cpufreq_governor`

> Setting governor to <value>

**Arguments:** exactly 1 argument(s)

---

### `power::_set_usb_autosuspend`

> Control=<value> delay=<value>ms

**Arguments:** exactly 2 argument(s)

---

### `power::apply_profile`

> Applying profile: <value>

Apply the named profile to the running kernel — requires root.
Called by power-profile.service on boot and by boxctl power apply.

**Arguments:** exactly 1 argument(s)

---

### `power::set_profile`

> Setting profile: <value>

Persist the profile and trigger the service to apply it.

**Arguments:** exactly 1 argument(s)

---
