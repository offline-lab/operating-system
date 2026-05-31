# Health — system status checks

**Source:** `framework/library/health.sh`

Device system status helpers for labctl. All functions require the framework to be sourced before this file. Requires: systemctl, df, free, cat (/sys/kernel/security/apparmor/profiles)

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

### `health::failed_units`

> Getting failed systemd units

---

### `health::failed_unit_count`

> Counting failed systemd units

---

### `health::apparmor_status`

> Getting apparmor status

---

### `health::verity_status`

> Getting dm-verity status

---

### `health::disk_usage`

> Getting disk usage for <value>

---

### `health::memory_usage`

> Getting memory usage

---

### `health::print_health`

> Printing system health summary

---
