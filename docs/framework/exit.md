# Exit — script termination helpers

**Source:** `framework/library/exit.sh`

Print to log and exit with exit_code

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## Exit functions for scripts                                                 ##

### `exit::log`

> Logging to output with <value> and exit <value>

---

### `exit::info`

> Logging ok and exiting

---

### `exit::ok`

---

### `exit::debug`

> Logging debug and exiting

---

### `exit::trace`

> Logging trace and exiting

---

### `exit::warning`

> Logging warning and exiting

---

### `exit::warn`

---

### `exit::error`

> Logging error and exiting

---

### `exit::err`

---

### `exit::fatal`

---

### `exit::die`

---

### `exit::stdin`

> Logging input

Print output in white from stdin with level INPUT and exit

---

### `exit::if_false`

> Error out when input is false

---

### `exit::if_true`

> Error out when input is true

Error out if input is true

---

### `exit::if_empty`

> Error out when input is empty

Error out if input is empty

---

### `exit::if_equals`

> Error out when input value1 equals value2

Error out if input is equal to

---
