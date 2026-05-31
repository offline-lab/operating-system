# Interaction — prompts and user input

**Source:** `framework/library/interact.sh`

Request confirmation

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

### `interact::prompt_bool`

> Asking the user for confirmation

---

### `interact::ask_for_permission`

> Asking for permissions

Ask for permissions

---

### `interact::prompt_response`

> Asking the user for input

Input

**Arguments:** at least 1 argument(s)

---

### `interact::usage`

> Checking if usage flag is present

Check if -h or --help is given in arguments

---

### `interact::active`

> Checking if session is interactive

Check if session is interactive

---
