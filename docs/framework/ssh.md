# SSH — key generation and agent management

**Source:** `framework/library/ssh.sh`

Generate a private key using dropbearkey. Passphrase-protected keys are not supported by dropbear key generation. Writes <keyfile>.pub alongside the private key.

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## SSH

### `ssh::generate_ssh_keypair`

> Generating ssh keypair

**Arguments:** at least 1 argument(s)

---

### `ssh::connect`

> Connecting over ssh to server

Open an interactive SSH session

**Arguments:** exactly 3 argument(s)

---

### `ssh::run`

> Running command over ssh

Run a command over SSH

**Arguments:** at least 4 argument(s)

---

### `ssh::test_connection`

> Testing ssh connection

Test SSH connection to a machine

**Arguments:** exactly 3 argument(s)

---

### `ssh::create_tunnel`

> Creating ssh tunnel

Create SSH tunnel

**Arguments:** exactly 6 argument(s)

---

### `ssh::port_available`

> Checking if port is available

Check if a port is available for a tunnel

**Arguments:** exactly 1 argument(s)

---
