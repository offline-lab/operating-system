# Build

This page describes how app packages are built and published using `buildctl`. It covers
the build flow, the signing model, and the publish workflow.

Full buildctl documentation (command reference, flags, configuration) lives in
`buildctl.git`. This page covers the concepts and the design decisions that implementors
need to understand.

---

## What buildctl does

`buildctl` is the developer-side CLI tool for building and publishing Offline Lab app
packages. It runs on a developer workstation or CI machine, not on an Offline Lab device.

1. Builds a squashfs image from a backend-specific source (Dockerfile, shell script, etc.)
2. Generates dm-verity companion files (`.roothash`, `.verity`)
3. Signs the roothash with the build key (`.roothash.p7s`)
4. Generates package metadata (`.json`)
5. Publishes to a repo via rsync + SSH index update

---

## Build backends

A **build backend** is responsible for exactly one thing: producing a filesystem that
becomes the squashfs image. Everything after that — squashfs conversion, dm-verity
generation, signing, metadata generation, packaging — is backend-agnostic and handled
by buildctl regardless of which backend was used.

The backend contract:
> Given a source directory and a target arch, produce a root filesystem tree (or tar
> archive). buildctl takes it from there.

This separation means the packaging pipeline (verity, signing, metadata) only needs to
be implemented once. Adding a new backend means implementing the filesystem production
step — nothing else changes.

### Supported backends

| Backend | Status | Use when |
|---|---|---|
| `docker` | v1, default | You have a Dockerfile; standard container workflow |
| `shell` | v1 | You have a `build.sh` script that produces a root filesystem |
| `make` | v1 | You have a `Makefile` with a target that produces a root filesystem |
| `mkosi` | v1 | You want a systemd-native image built from distro packages without a container runtime |

**Specifying a backend:**

```yaml
# package.yaml
backend: docker    # default if omitted
```

Or via flag: `buildctl build --backend docker <dir>`

**Backend-specific arguments:**

Each backend accepts optional arguments via `backend_arguments` in `package.yaml`. The
valid keys depend on the selected backend and are defined in each backend's section below.

```yaml
backend: docker
backend_arguments:
  no_cache: true
  build_args:
    VERSION: "2.0.18"
```

`backend_arguments` is a freeform map — buildctl validates the key names it knows about
for the selected backend and ignores unknown keys with a warning. Per-backend argument
definitions are documented alongside each backend.

### Package config file

buildctl reads the package config from `package.yaml` or `package.json` in the source
directory. Both formats use the same schema (`docs/schemas/package-yaml.schema.json`);
`package.json` is JSON-encoded rather than YAML. If both files are present, buildctl
exits with an error. If neither is present, buildctl exits with an error.

### .buildignore

A `.buildignore` file in the source directory lists files and directories to exclude
from the squashfs. buildctl applies these rules **after the backend exports the root
filesystem, before mksquashfs runs**. The format is identical to `.dockerignore`:

- One pattern per line
- Lines starting with `#` are comments
- `!` prefix negates a pattern (re-include after a previous exclusion)
- Standard glob patterns; `**` matches any number of path segments

The `.buildignore` file affects the squashfs contents only. It does not affect what the
backend sees during its own build step (for Docker, use `.dockerignore` for that).

### Docker backend

The Docker backend builds a container image from a `Dockerfile` and exports the
filesystem using `docker buildx`. It is the v1 default and requires Docker with
buildx.

**Source layout:**

```
myapp/
  Dockerfile           ← builds the service image
  package.yaml         ← package metadata and runtime configuration
  .buildignore         ← optional: files to exclude from the squashfs
```

The Dockerfile is the maintainer's responsibility — buildctl does not generate it.

**Cross-compilation:** the Docker backend uses `docker buildx` with QEMU emulation.
On macOS and x86 Linux machines, building for `arm64` requires:

```
docker buildx create --use
docker run --privileged --rm tonistiigi/binfmt --install arm64
```

After setup, `buildctl build --arch arm64` transparently builds for arm64 via buildx.
No separate toolchain or native arm64 machine is needed for standard Dockerfiles.
For Dockerfiles that invoke native compilers, emulation is slow — a native arm64
build machine is faster for those cases.

### mkosi backend (planned)

[mkosi](https://github.com/systemd/mkosi) builds bootable OS images and filesystem
trees directly from distribution packages, without a container runtime. It is developed
by the systemd project and produces clean, minimal images with explicit package manifests.

For portable services, mkosi is an interesting fit: images are built from distro packages
(not layers), the result is a plain filesystem tree, and integration with systemd tooling
is first-class. No Docker installation required on the build machine.

The mkosi backend is not implemented in v1. It is planned as a first-class alternative
backend when buildctl.git is being built out.

---

## Build pipeline (backend-agnostic)

Once the backend produces a filesystem tree, buildctl runs the same pipeline regardless
of which backend was used:

```
buildctl build <dir>
```

1. **Read** `package.yaml` — validate all required fields
2. **Invoke backend** — produce a root filesystem tree for the target arch
3. **Convert** to squashfs: `mksquashfs <rootfs> <name>.squashfs -noappend -comp zstd`
4. **Embed** `package.yaml` into the squashfs at `/usr/share/<name>/package.yaml`
5. **Generate** verity companion files:
   ```
   veritysetup format <name>.squashfs <name>.squashfs.verity
   ```
   Produces the root hash (hex) written to `<name>.squashfs.roothash`
6. **Sign** the roothash with the build key:
   ```
   openssl cms -sign -in <name>.squashfs.roothash \
       -signer <name>.crt -inkey <name>.key \
       -out <name>.squashfs.roothash.p7s -outform DER -nodetach
   ```
7. **Generate** metadata JSON (`<name>-<version>-<arch>.json`) from `package.yaml` fields
   plus `squashfs_size` and `created_at`
8. **Package** all five files into a zip for transport:
   ```
   <name>-<version>-<arch>.squashfs
   <name>-<version>-<arch>.squashfs.roothash
   <name>-<version>-<arch>.squashfs.roothash.p7s
   <name>-<version>-<arch>.squashfs.verity
   <name>-<version>-<arch>.json
   ```

Output directory: `./dist/` by default, configurable with `--out`.

---

## Signing keys

### Build key (high trust — build machine only)

The build key signs `.roothash.p7s` for every package. It never leaves the build machine.

Generate a build keypair:

```
buildctl key generate --name <repo-name> --out ./keys/
```

Produces `<repo-name>.key` (private, keep secret) and `<repo-name>.crt` (public,
published to repo). The `.key` file must never be:
- Copied to the repo server
- Committed to version control
- Accessible to CI systems without a secrets manager

Treat it like a CA private key.

### Index key (lower trust — repo host)

The index key signs `index.json.p7s` for each arch index after each publish. It lives on
the repo host and is used automatically by the index update step of `buildctl publish`.

Generate an index keypair on the repo host:

```
buildctl key generate --name <repo-name>-index --index --out ./keys/
```

Produces `<repo-name>-index.key` and `<repo-name>-index.crt`. The `--index` flag marks
this cert as an index-signing key. Store the `.key` on the repo host, publish the
`.crt` alongside the build cert in `keys/`.

A compromised index key cannot forge package signatures — appctl always verifies the
build-key signature on the package itself at install time. The blast radius of an index
key compromise is limited to catalog manipulation (advertise stale versions, hide
packages); it does not allow injecting malicious package content.

---

## Publish flow

Publishing has two distinct steps, on two different machines.

### Step 1 — Push package files (build machine → repo host)

```
buildctl publish --repo <host>:<path> <dist-dir>/<package-files>
```

Rsyncs the five package files (squashfs + companions + metadata) and the zip to the
correct path on the repo host:

```
rsync -az dist/ <user>@<host>:<repo-root>/packages/<arch>/<name>/<version>/
```

No index writing happens in this step. No index key is needed on the build machine.

### Step 2 — Update the index (repo host, via SSH)

```
buildctl index update --repo <host>:<path> --package <name> --arch <arch>
```

SSHs to the repo host and runs an atomic index update there:

1. Acquire a local lock (`flock`) on the repo's index lock file to prevent concurrent writers
2. Download the current arch `packages/<arch>/index.json`
3. Add or replace the entry for `<name>` with the new version data
4. Write the updated `index.json`
5. Sign it with the index key (local to the repo host):
   ```
   buildctl index sign packages/<arch>/index.json --key <repo-name>-index.key
   ```
6. Update and sign the root `index.json` (keys array + arches listing)
7. Release the lock

The index key never leaves the repo host. The build machine does not need it.

### Combined publish shorthand

```
buildctl publish --repo <host>:<path> --push --update-index <dist-dir>/
```

Runs both steps in sequence. Equivalent to calling the two commands above.

---

## Incremental index update

`buildctl index update` downloads the current index, patches one entry, and re-signs.
It does not require all packages to be present locally. This is the normal publish
workflow — full regeneration from scratch is only needed when bootstrapping a new repo
or after an option B key rotation.

---

## Validation

buildctl provides two validation subcommands covering different phases of the build lifecycle.

### buildctl validate project <dir>

Pre-build validation. Checks the source directory without invoking any backend.

- Detects `package.yaml` or `package.json` (error if both present, error if neither present)
- Validates all required fields are present and correctly typed
- Validates `lifecycle` block: absent or all values are non-empty unit name strings
- Validates `systemd_profile` is one of the known values
- Validates `resources` estimates are within plausible bounds (advisory warning, not error)
- Validates `version` is valid semver
- Checks that the required backend source file exists (`Dockerfile` for docker, `build.sh`
  for shell, `Makefile` for make, `mkosi.conf` for mkosi)
- If `.buildignore` is present: validates pattern syntax

Build fails on any validation error. Warnings are printed but do not block the build.

### buildctl validate image <dist-dir>

Post-build validation. Checks the output in `dist/` after a successful `buildctl build`.

- Verifies all five required files are present and correctly named
- Validates the metadata JSON against the package metadata schema
- Lists squashfs contents and checks required files inside the image:
  - `/etc/os-release` with `ID=<name>` and `VERSION_ID=<version>` matching the metadata
  - `/usr/lib/systemd/system/<name>.service`
  - `/usr/lib/systemd/system/<name>.socket` if `socket_activation: true`
  - All lifecycle hook unit files declared in the metadata
- Verifies the `.roothash.p7s` signature against the provided build certificate
- Verifies the dm-verity hash tree against the root hash

```
buildctl validate image ./dist --cert ./keys/myrepo.crt
```

Path comparisons inside the squashfs are always case-sensitive, regardless of the host
filesystem. This matters on macOS (HFS+ is case-insensitive by default).

---

## Dockerfile labels (optional)

buildctl reads standard OCI labels from the Docker image to populate metadata fields.
If a label is present and the matching `package.yaml` field is empty, the label value
is used. Explicit `package.yaml` fields always win.

| OCI label | package.yaml field |
|---|---|
| `org.opencontainers.image.title` | `name` |
| `org.opencontainers.image.version` | `version` |
| `org.opencontainers.image.description` | `description` |
| `org.opencontainers.image.url` | `homepage` |
| `org.opencontainers.image.source` | `source_url` |
| `org.opencontainers.image.licenses` | `license` |
| `org.opencontainers.image.vendor` | `publisher` |

These labels are standard practice in Dockerfile authoring — buildctl will use them
if present. They are not required.

---

## Key rotation

See [Security Model — Key Rotation](security-model.md#key-rotation) for the full design.

For builds: `buildctl build --key <new-key>` uses the specified build key. New packages
are signed with the new key; old packages keep their existing signatures. Both certs
must be published in the repo's `keys[]` during the transition window.

For option B (re-sign all): `buildctl rebuild --all` (T65, backlog) re-signs every
package in a local checkout with the current build key and triggers a full index update.
This is documented as an alternative for operators who prefer a clean cut-over on small
repos; option A (gradual rotation) is recommended for most cases.

---

## Distributing buildctl

buildctl is distributed as a Debian package for developer workstations and CI machines.
Install with:

```
apt install buildctl
```

The Debian package is built from `buildctl.git` and published to the Offline Lab
package server. It is not an app package — it is a host-side development tool and does
not use the squashfs / portablectl app format.
