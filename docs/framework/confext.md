# confext

**Source:** `framework/library/confext.sh`

Configuration extension (confext) operations via systemd-confext. All mutating functions require root (called via priv::run).

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

### `confext::list`

> Listing configuration extensions

---

### `confext::status`

> Showing configuration extension merge status

---

### `confext::merge`

> Merging configuration extensions

---

### `confext::unmerge`

> Unmerging configuration extensions

---

### `confext::refresh`

> Refreshing configuration extensions (unmerge + merge)

---

### `confext::storage_dir`

> Returning confext storage directory

---
