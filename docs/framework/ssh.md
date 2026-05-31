# SSH — key generation and agent management

**Source:** `framework/library/ssh.sh`

Generate a private key for SSH to instance

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## SSH

### `ssh::generate_ssh_keypair`

> Generating ssh keypair

**Arguments:** at least 1 argument(s)

---

### `ssh::start_agent`

> Starting ssh-agent

Start ssh agent

---

### `ssh::stop_agent`

> Killing ssh-agent

Stop ssh agent

**Arguments:** exactly 1 argument(s)

---

### `ssh::add_key`

> Adding key to ssh-agent

Add key to ssh agent

**Arguments:** at least 2 argument(s)

---

### `ssh::rm_key`

> Removing ssh key from ssh agent

Remove key from ssh agent

**Arguments:** exactly 2 argument(s)

---

### `ssh::connect`

> Connecting over ssh to server

Setup an SSH connection to the server

**Arguments:** exactly 3 argument(s)

---

### `ssh::run`

> Running command over ssh

Run an SSH command

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

Check if the tunnel can be created

**Arguments:** exactly 1 argument(s)

---
