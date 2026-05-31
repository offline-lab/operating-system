# Cache — key/value store with TTL

**Source:** `framework/library/cache.sh`

Initialize cache

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

### `cache::setup`

> Initializing cache in <value>

---

### `cache::is_initialized`

> Checking if cache key is initialized

Check of cache is initialized

---

### `cache::warning`

> Checking if cache is initialized

Print a warning if cache is not initialized

---

### `cache::exists`

> Checking if cache key <value> exists

Check if cache item exists

**Arguments:** exactly 1 argument(s)

---

### `cache::get`

> Retrieving key from cache

Get key from cache

**Arguments:** exactly 1 argument(s)

---

### `cache::set`

> Setting <value>:<value> in cache

Set key in cache

**Arguments:** exactly 2 argument(s)

---

### `cache::flush`

> Flushing <value> from cache

Remove key from cache

**Arguments:** exactly 1 argument(s)

---

### `cache::flushall`

> Flushing all keys from cache

Clear out the cache

---
