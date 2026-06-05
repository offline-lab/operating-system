# System — privilege escalation and sudo keepalive

**Source:** `framework/library/system.sh`

Run a command as root. If already root: exec directly. If not: delegate to sudo boxctl-su, which enforces the /etc/boxctl/su.conf allowlist.

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

### `priv::run`

> Running privileged command: <value>

**Arguments:** at least 1 argument

---

### `system::sudo_keepalive`

> Starting sudo keepalive background process

Keep sudo credentials alive in the background.
Call once at the start of a long-running privileged script.

---
