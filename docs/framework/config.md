# Config — /data/config key/value store

**Source:** `framework/library/config.sh`

/data/config read/write helpers for labctl. All functions require the framework to be sourced before this file.

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

### `config::ensure_writable`

> Checking <value> is writable

---

### `config::read`

> Reading <value>

**Arguments:** exactly 1 argument(s)

---

### `config::write`

> Writing <value>

**Arguments:** exactly 2 argument(s)

---

### `config::delete`

> Deleting <value>

**Arguments:** exactly 1 argument(s)

---

### `config::list`

> Listing config keys

---

### `config::apply_hostname`

> Applying hostname from config

---

### `config::apply_timezone`

> Applying timezone from config

---
