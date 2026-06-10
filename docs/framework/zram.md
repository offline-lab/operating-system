# zram

**Source:** `framework/library/zram.sh`

zram swap management. Requires: zramctl, mkswap, swapon, swapoff, modprobe (all privileged).

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## zram::_calc — evaluate a floating-point arithmetic expression via awk

### `zram::_calc`

> <value>

**Arguments:** at least 1 argument

---

## zram::_comp_factor — default compression ratio for given algorithm

### `zram::_comp_factor`

> <value>

---

## zram::_remove_device — reset a single zram block device

### `zram::_remove_device`

> Removing <value>

**Arguments:** exactly 1 argument(s)

---

## zram::start — load module, allocate device, mkswap + swapon

### `zram::start`

> Starting zram swap

---

## zram::stop — swapoff + remove all zram devices

### `zram::stop`

> Stopping zram swap

---
