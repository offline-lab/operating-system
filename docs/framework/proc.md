# Process — command execution and output handling

**Source:** `framework/library/proc.sh`

Run a command silently; print combined output only on failure. Bash port of moreutils chronic(1) — https://joeyh.name/code/moreutils/

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## Run a command and handle output

### `proc::chronic`

> Running command with output suppressed unless failure

**Arguments:** at least 1 argument

---

### `proc::assert_command`

> Running command and capturing output

Run a command and send all output to a file

**Arguments:** at least 2 argument(s)

---

### `proc::log_output`

> Running command and sending output to log

Run a command and send all output to logger

**Arguments:** at least 2 argument(s)

---

### `proc::log_action`

> Running command and logging output by exit code

Run a command and log the output based on it's exit code

**Arguments:** at least 1 argument(s)

---

### `proc::watch`

> Watching command

Watch a command

**Arguments:** at least 1 argument(s)

---

### `proc::run`

> Running command silently

Run a command silently; echoes "true"/"false" to stdout, returns 0/1.

**Arguments:** at least 1 argument(s)

---

### `proc::runall`

> Running list of commands

Run a set of commands and return a list of trues and/or falses

**Arguments:** at least 1 argument(s)

---

### `proc::all`

> Running all check

Return zero if all commands succeed

**Arguments:** at least 1 argument(s)

---

### `proc::any`

> Running any check

Return zero if any of the commands succeed

**Arguments:** at least 1 argument(s)

---

### `proc::none`

> Running none check

Return zero if none of the commands succeed

**Arguments:** at least 1 argument(s)

---
