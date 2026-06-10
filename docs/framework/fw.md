# fw

**Source:** `framework/library/fw.sh`

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## fw::flush — clear all nftables rules

### `fw::flush`

> Flush ruleset and clear state

---

## fw::down — explicit "firewall is down" with a log warning

### `fw::down`

> Bring firewall completely down

---

## fw::_load_static — load static rules from rootfs

### `fw::_load_static`

> Load static rules from <value>

---

## fw::_load_apps — replay all per-app rule fragments

### `fw::_restore_fragment`

**Arguments:** exactly 1 argument(s)

---

### `fw::_load_apps`

> Load app rule fragments from <value>

---

## fw::up — full bring-up: flush + static + apps

### `fw::up`

> Bring firewall up

---

## fw::reload — alias for fw::up

### `fw::reload`

> Reload all firewall rules

---

## fw::reset — static rules only, drop all app rules from memory

### `fw::reset`

> Reset to static rules only

---

## fw::init — bring up only if not already up (idempotent; safe for systemd)   #

### `fw::init`

> Initialize firewall if not already up

fw::init — bring up only if not already up (idempotent; safe for systemd)   #

---

## fw::app_allow <app> <proto> <port>

### `fw::app_allow`

> Allow <value>/<value> for app <value>

**Arguments:** exactly 3 argument(s)

---

## fw::app_remove <app>

### `fw::app_remove`

> Remove app <value> firewall rules

**Arguments:** exactly 1 argument(s)

---

## fw::list

### `fw::list`

> List current firewall rules

---
