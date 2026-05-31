# Arguments — CLI flag parsing

**Source:** `framework/library/arguments.sh`

Format the --flag into a variable name

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

### `arguments::get_variable_name`

> Get the variable name for a script argument

---

### `arguments::parse_arguments`

> Parse arguments

Parse the arguments into a dict

---

### `arguments::in_args`

> Checking if flag is present in arguments

Check if a specific argument is given

**Arguments:** at least 2 argument(s)

---
