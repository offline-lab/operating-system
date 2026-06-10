# resources

**Source:** `framework/library/resources.sh`

Host resource measurement and baseline read/write. Written at boot by offlinelab-resources.service via resources::snapshot.

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## Measurement — live reads from /proc and /sys

### `resources::cpu_cores`

> Reading cpu count

---

### `resources::total_memory_mb`

> Reading total memory

---

### `resources::used_memory_mb`

> Reading used memory

---

### `resources::total_storage_mb`

> Reading <value> total size

---

## Write — snapshot measurements to JSON

### `resources::snapshot`

> Writing resource snapshot to <value>

---

## Read — query the JSON snapshot

### `resources::get`

> Reading key from resources.json

**Arguments:** exactly 1 argument(s)

---

### `resources::available_memory`

> Calculating available memory

---

### `resources::available_storage`

> Reading available <value> storage

---
