# Network — IP, FQDN, email validation

**Source:** `framework/library/net.sh`

REQUIRES INTERNET Fetches the public IP of the local connection via curl.

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## Network and Internet related helpers

### `net::get_ip`

!!! warning "Requires internet"
    This function makes a network connection.

> Get the ip address of the local connection

---

## Validation — no network required

### `net::is_ip4`

> Checking if <value> is a valid ipv4 address

---

### `net::is_ip6`

> Checking if <value> is a valid ipv6 address

---

### `net::is_fqdn`

> Checking if <value> is a valid fqdn

---

### `net::is_email`

> Checking if <value> is a valid email address

---

## HTTP timing — REQUIRES INTERNET

### `net::http::time`

!!! warning "Requires internet"
    This function makes a network connection.

> Get timing for a http request

---
