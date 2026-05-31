# Core — bootstrap and module loader

**Source:** `framework/library/core.sh`

This is a special library. To prevent chicken and egg problems, we source directly instead of using our import function.

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

*No public functions.*