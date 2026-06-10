# Framework — API Reference

The offline-lab-framework is a bash utility library installed at `/usr/lib/framework/` on the Offline Lab OS. Scripts load it with `source framework || exit 1`.

See [Building the OS](../builder/) for buildroot packaging details.

## CLI

| Command | Description |
|---|---|
| [boxctl](commands.md) | Device management CLI |

## Utility modules

| Module | Description | Functions |
|---|---|---|
| [`arguments`](arguments.md) | CLI flag parsing | 3 |
| [`array`](array.md) | operations and predicates | 31 |
| [`cache`](cache.md) | key/value store with TTL | 8 |
| [`clock`](clock.md) | clock | 2 |
| [`confext`](confext.md) | confext | 6 |
| [`credentials`](credentials.md) | random username and password generation | 2 |
| [`depends`](depends.md) | tool availability checks | 7 |
| [`files`](files.md) | merge and deduplication | 2 |
| [`fs`](fs.md) | path and file checks | 16 |
| [`fw`](fw.md) | fw | 12 |
| [`interact`](interact.md) | prompts and user input | 5 |
| [`net`](net.md) | IP, FQDN, email validation | 6 |
| [`power`](power.md) | power | 8 |
| [`prettytable`](prettytable.md) | Unicode terminal table output | 4 |
| [`proc`](proc.md) | command execution and output handling | 10 |
| [`resources`](resources.md) | resources | 8 |
| [`ssh`](ssh.md) | key generation and agent management | 6 |
| [`ssl`](ssl.md) | certificate and key validation | 23 |
| [`string`](string.md) | manipulation and comparison | 17 |
| [`sysext`](sysext.md) | sysext | 6 |
| [`system`](system.md) | privilege escalation and sudo keepalive | 3 |
| [`time`](time.md) | formatting and timestamps | 2 |
| [`var`](var.md) | type and value checks | 30 |
| [`zram`](zram.md) | zram | 5 |

## OS-specific modules

| Module | Description | Functions |
|---|---|---|
| [`config`](config.md) | /data/config key/value store | 7 |
| [`health`](health.md) | system status checks | 7 |
| [`rauc`](rauc.md) | A/B OTA update operations | 15 |
| [`system`](system.md) | privilege escalation and sudo keepalive | 3 |
| [`wifi`](wifi.md) | wpa_supplicant management | 11 |

## Framework internals

| Module | Description | Functions |
|---|---|---|
| [`core`](core.md) | bootstrap and module loader | 0 |
| [`debug`](debug.md) | stack trace and error handling | 5 |
| [`exit`](exit.md) | script termination helpers | 16 |
| [`import`](import.md) | module loading and circular import prevention | 4 |
| [`logging`](logging.md) | leveled output to stderr | 14 |
| [`sanity`](sanity.md) | pre-execution checks | 1 |
