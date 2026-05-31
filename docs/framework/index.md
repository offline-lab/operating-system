# Framework — API Reference

The offline-lab-framework is a bash utility library installed at `/usr/lib/framework/` on the Offline Lab OS. Scripts load it with `source framework || exit 1`.

See [Framework Integration](../framework-integration/) for buildroot packaging details.

## CLI

| Command | Description |
|---|---|
| [labctl](commands.md) | Device management CLI |

## Utility modules

| Module | Description | Functions |
|---|---|---|
| [`arguments`](arguments.md) | CLI flag parsing | 3 |
| [`array`](array.md) | operations and predicates | 31 |
| [`cache`](cache.md) | key/value store with TTL | 8 |
| [`credentials`](credentials.md) | random username and password generation | 2 |
| [`depends`](depends.md) | tool availability checks | 7 |
| [`files`](files.md) | merge and deduplication | 1 |
| [`fs`](fs.md) | path and file checks | 16 |
| [`interact`](interact.md) | prompts and user input | 5 |
| [`net`](net.md) | IP, FQDN, email validation | 6 |
| [`prettytable`](prettytable.md) | Unicode terminal table output | 4 |
| [`proc`](proc.md) | command execution and output handling | 10 |
| [`ssh`](ssh.md) | key generation and agent management | 10 |
| [`ssl`](ssl.md) | certificate and key validation | 23 |
| [`string`](string.md) | manipulation and comparison | 17 |
| [`system`](system.md) | privilege escalation and sudo keepalive | 2 |
| [`time`](time.md) | formatting and timestamps | 2 |
| [`var`](var.md) | type and value checks | 30 |

## OS-specific modules

| Module | Description | Functions |
|---|---|---|
| [`config`](config.md) | /data/config key/value store | 7 |
| [`health`](health.md) | system status checks | 7 |
| [`rauc`](rauc.md) | A/B OTA update operations | 15 |
| [`system`](system.md) | privilege escalation and sudo keepalive | 2 |
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
