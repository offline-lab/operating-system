# Contributing

Offline Lab is an open-source community project under AGPL v3. Contributions are welcome.

## Getting started

1. Browse the [GitHub organization](https://github.com/offline-lab) to find a repository.
2. Read the repository README for build instructions.
3. Check the issue tracker for open issues, or create one to discuss your idea before starting.

For build setup and coding conventions, see the [Development guide](development.md).

## Repositories

| Repository | Description |
|---|---|
| [builder](https://github.com/offline-lab/builder) | Offline Lab OS image builder (Buildroot), framework, boxctl, and on-device tooling |
| [disco](https://github.com/offline-lab/disco) | Service discovery and name resolution for offline networks |
| services | Portable systemd service images (planned) |
| sync | Data synchronization tools (planned) |

## Framework

The [Framework](framework/index.md) is the most actively developed part of the codebase. It's a Bash utility library installed on every Offline Lab OS device. See the [framework contributor guide](https://github.com/offline-lab/builder/blob/main/framework/.claude/CLAUDE.md) for coding conventions, and run `bin/test-framework --lint` before submitting changes.

## Submitting a pull request

### 1. Fork and branch

Use `feature/<short-description>` for new features, `fix/<short-description>` for bug fixes.

```bash
git clone git@github.com:<your-username>/<repo>.git
cd <repo>
git checkout -b my-change
```

### 2. Make your change

Keep changes small and focused: one concern per PR. Match the existing code style. Don't include unrelated cleanups or formatting. Test locally before submitting.

### 3. Commit

Write a clear message that says what changed and why:

```
Add WiFi credential loading from /boot/firmware

Reads wpa_supplicant configuration from the boot partition
so users can configure WiFi without a serial console.
```

### 4. Push and open a PR

```bash
git push origin my-change
```

Open a pull request against `main` on the upstream repository. In the description, summarize the change, how you tested it, and link related issues.

### 5. Review

A maintainer will review your PR. Changes may need revision before merging.

## Reporting issues

Open an issue in the relevant repository. Include what you expected, what happened, and steps to reproduce.

## Code of conduct

Be respectful and constructive. We build tools for communities. The project should reflect that.
