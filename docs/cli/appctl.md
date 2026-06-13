# appctl

appctl is the on-device CLI for installing and managing app packages on Offline Lab OS. It handles the full lifecycle of portable services: repo management, install, update, rollback, and removal.

Source: [github.com/offline-lab/appctl](https://github.com/offline-lab/appctl) · Docs: [appctl.offline-lab.com](https://appctl.offline-lab.com)

## What it does

Apps ship as signed squashfs images (portable services). appctl verifies signatures, allocates per-app system users, manages storage, and wires services into systemd via `portablectl`. See [Service model](../components.md) and [Package format](../specs/package-format.md) for the design.

## Planned subcommands

| Command | What it does |
|---|---|
| `repo add <url>` | Add a package repository and import its signing keys |
| `repo remove <name>` | Remove a repository and its stored keys |
| `repo refresh` | Re-download and verify the package index |
| `search <term>` | Search available packages by name, description, or tags |
| `install <name>` | Download, verify, and install a package |
| `remove <name>` | Stop and detach a package (data retained unless `--purge`) |
| `update <name>` | Install a newer version of an installed package |
| `rollback <name>` | Roll back to the previous image version |
| `list` | Show installed packages, versions, and status |
| `cleanup` | Remove orphaned data from previously removed packages |
| `rehydrate` | Re-attach all installed packages (runs at boot via `restore-apps.service`) |

## Signing and verification

Every package is signed with a build key. appctl verifies the PKCS7 signature against the repository's public cert before writing anything to disk. See [Security model](../specs/security-model.md) for the full trust chain.

## Resource checks

Before installing, appctl compares the package's declared resource estimates against the device's available memory and storage. See [Resource tracking](../specs/resource-tracking.md).
