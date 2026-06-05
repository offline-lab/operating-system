# WiFi — wpa_supplicant management

**Source:** `framework/library/wifi.sh`

WiFi management via wpa_cli for boxctl. All functions require the framework to be sourced before this file. Requires: wpa_cli (privileged — called via priv::run), ip

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

### `wifi::cli`

> Wpa_cli <value>

---

### `wifi::state`

> Getting wpa_supplicant state

---

### `wifi::is_connected`

> Checking if wifi is connected

---

### `wifi::current_ssid`

> Getting current ssid

---

### `wifi::current_ip`

> Getting current ip on <value>

---

### `wifi::scan`

> Triggering wifi scan

---

### `wifi::list_networks`

> Listing configured networks

---

### `wifi::connect`

> Connecting to <value>

**Arguments:** at least 2 argument(s)

---

### `wifi::status`

---

### `wifi::print_status`

> Printing wifi status

---

### `wifi::print_scan`

> Printing scan results

---
