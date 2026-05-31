# Filesystem — path and file checks

**Source:** `framework/library/fs.sh`

Check if directory and existent

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## FS:: Filesystem helpers                                                    ##

### `fs::is_dir`

> Checking if directory exists

**Arguments:** exactly 1 argument(s)

---

### `fs::is_file`

> Checking if file exists

**Arguments:** exactly 1 argument(s)

---

### `fs::is_blockdev`

> Checking if block device exists

**Arguments:** exactly 1 argument(s)

---

### `fs::is_device`

---

### `fs::is_socket`

> Checking if socket exists

**Arguments:** exactly 1 argument(s)

---

### `fs::is_chardev`

> Checking if char device exists

Check if input is a character special device

**Arguments:** exactly 1 argument(s)

---

### `fs::is_pipe`

> Checking if pipe exists

**Arguments:** exactly 1 argument(s)

---

### `fs::is_port`

> Checking if port is in use

Check if open port / listening socket

**Arguments:** exactly 1 argument(s)

---

### `fs::is_link`

> Checking if symlink exists

**Arguments:** exactly 1 argument(s)

---

### `fs::is_executable`

> Checking if file is executable

**Arguments:** exactly 1 argument(s)

---

### `fs::exists`

> Checking if path exists

**Arguments:** exactly 1 argument(s)

---

### `fs::is_regex`

> Checking if file matches regex

Check if file matches regex

---

### `fs::regex_count`

> Checking how many times regex matches in file

Check how many times a regex occurs in a file

---

## Directory helper functions

### `fs::in_dir`

> Check if directory containing file exists

Check if the directory of a file exists

---

### `fs::ensure_dir`

> Making sure directory exists

Make sure the directory of a file exists

---

### `fs::ensure_file_in_dir`

> Making sure file exists in directory

Make sure a directory and a file exist

---
