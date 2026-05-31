# Dependencies — tool availability checks

**Source:** `framework/library/depends.sh`

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## Check if user is root

### `depends::is_root`

> Checking if current user is superuser

---

## Check if dependency is found in PATH

### `depends::in_path`

> Checking if dependency is in path

**Arguments:** exactly 1 argument(s)

---

## Check if dependency is executable

### `depends::executable`

> Checking if dependency is executable

**Arguments:** exactly 1 argument(s)

---

## Silently check if dependency exists

### `depends::check::silent`

> Checking if dependency exists

**Arguments:** exactly 1 argument(s)

---

## Check if dependency exists (and log it)

### `depends::check`

> Checking for required dependency

**Arguments:** exactly 1 argument(s)

---

## Check silently if a list of dependencies exist

### `depends::check_list::silent`

> Checking list of dependencies silently

**Arguments:** at least 1 argument(s)

---

## Check if a list of dependencies exist (and log it)

### `depends::check_list`

> Checking for list of dependencies

**Arguments:** at least 1 argument(s)

---
