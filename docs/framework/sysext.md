# sysext

**Source:** `framework/library/sysext.sh`

System extension (sysext) operations via systemd-sysext. All mutating functions require root (called via priv::run).

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

### `sysext::list`

> Listing system extensions

---

### `sysext::status`

> Showing system extension merge status

---

### `sysext::merge`

> Merging system extensions

---

### `sysext::unmerge`

> Unmerging system extensions

---

### `sysext::refresh`

> Refreshing system extensions (unmerge + merge)

---

### `sysext::storage_dir`

> Returning sysext storage directory

---
