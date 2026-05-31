# RAUC — A/B OTA update operations

**Source:** `framework/library/rauc.sh`

RAUC slot and bundle operations for labctl. All functions require the framework to be sourced before this file. Requires: rauc (privileged — called via priv::run), jq

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

### `rauc::status_json`

> Getting rauc status json

---

### `rauc::active_slot`

> Getting active rauc slot name

---

### `rauc::slots`

> Listing all rauc slot names

---

### `rauc::slot_field`

> Getting field <value> for slot <value>

**Arguments:** exactly 2 argument(s)

---

### `rauc::slot_version`

> Getting version for slot <value>

**Arguments:** exactly 1 argument(s)

---

### `rauc::slot_state`

> Getting state for slot <value>

**Arguments:** exactly 1 argument(s)

---

### `rauc::slot_bootname`

> Getting bootname for slot <value>

**Arguments:** exactly 1 argument(s)

---

### `rauc::find_bundle`

> Searching for rauc bundles in <value>

---

### `rauc::bundle_compatible`

> Getting compatible string from bundle <value>

**Arguments:** exactly 1 argument(s)

---

### `rauc::bundle_version`

> Getting version from bundle <value>

**Arguments:** exactly 1 argument(s)

---

### `rauc::install`

> Installing rauc bundle <value>

**Arguments:** exactly 1 argument(s)

---

### `rauc::inactive_slot`

> Finding inactive rootfs slot

---

### `rauc::mark_good`

> Marking current boot slot as good

---

### `rauc::mark_active`

> Marking slot <value> as active for next boot

**Arguments:** exactly 1 argument(s)

---

### `rauc::print_slots`

> Printing slot table

---
