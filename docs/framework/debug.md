# Debug — stack trace and error handling

**Source:** `framework/library/debug.sh`

Output failures message for functions that are not returning exit status 0 ref: https://github.com/bash-utilities/trap-failure/

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

### `debug::handle_error`

shellcheck disable=SC2154

---

### `debug::set_debug`

Enable debug mode

---

### `debug::unset_debug`

Disable debug mode

---

### `debug::set_silent`

Set silent mode

---

### `debug::unset_silent`

Unset silent mode

---
