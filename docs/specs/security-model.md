# Security Model

This page describes the trust chain for app packages, how signing keys are managed,
and what each security mechanism protects against.

---

## Trust chain

```
build key  (private, on build machine only, never on repo server)
  └── <name>.squashfs.roothash.p7s   ← PKCS7 signature over the root hash
        └── <name>.squashfs.roothash ← dm-verity root hash
              └── <name>.squashfs.verity ← hash tree over every squashfs block
                    └── <name>.squashfs  ← image blocks, verified at read time

index.json.p7s  ← PKCS7 signature over the repo index
  └── index.json ← package listing, verified at repo refresh
```

The build key never touches the repo server. A compromised repo server can replace
files, but cannot forge valid signatures without the build key.

---

## What each layer protects

| Layer | Protects against |
|---|---|
| `index.json.p7s` | Index tampering (MITM on HTTP, USB drive modification, downgrade attacks) |
| `.roothash.p7s` | Package tampering in transit or on the repo server |
| `.squashfs.roothash` | Mismatch between declared hash and actual image |
| `.squashfs.verity` | Block-level tampering of the squashfs at runtime (every read verified) |
| dm-verity (runtime) | Post-install tampering of the squashfs on the system |
| appctl p7s verify (install) | Confirms package is from the declared repo before writing to disk |

---

## Signing keys

Two independent signing keys are used for app packages. They have different trust
levels, live on different machines, and must never be mixed up.

### Build key — package integrity (high trust)

Lives on the **build machine only**. Never copied to the repo server. Never committed
to version control.

- `<repo>.key` — private build key. Signs `.roothash.p7s` for every package.
- `<repo>.crt` — public certificate. Published in the repo's `keys/` directory.
  Imported by `appctl repo add`. Safe to share publicly.

Loss of this key means the repo can no longer publish signed packages. A compromised
build key means an attacker can forge package signatures — treat it like a CA key.

### Index key — catalog integrity (lower trust)

Lives on the **repo host**. Signs `index.json.p7s` for each arch index after a
publish. Can be stored on the repo server because its blast radius is limited: a
compromised index key lets an attacker manipulate the package catalog (advertise old
versions, hide packages) but **cannot forge package content**. appctl always verifies
the build-key signature on the package itself at install time regardless of what the
index says.

- `<repo>-index.key` — private index key. Stays on the repo host.
- `<repo>-index.crt` — public certificate. Also published in `keys/`. appctl uses it
  to verify the index; it does not use it to verify packages.

These are separate certs with separate `key_id` values. appctl knows which is which
from the `keys[]` array in the root index and from the `signing_key_id` on each
package entry (which always points to the build key cert).

### RAUC OTA signing

RAUC uses a separate PKI for signing update bundles (`.raucb` files):

- `.rauc/ca.cert.pem` — CA certificate baked into the OS image at build time.
  Devices use this to verify update bundles.
- `.rauc/ca.key.pem` — CA private key. Stays on the signing machine, never in the
  image, never committed.
- `.rauc/cert.pem` / `.rauc/key.pem` — signing cert/key used by `rauc bundle`.

These are distinct from app package signing keys. The RAUC PKI covers OS update
integrity; app signing covers individual package integrity. Both use PKCS7 but
with separate key material and separate verification paths.

The `.rauc/` directory is gitignored. See the build docs for how to provision it.

---

## Key creation

Generate a build keypair on the build machine:

```
buildctl key generate --name offline-lab --out ./keys/
```

Produces `offline-lab.key` (secret, stays on build machine) and `offline-lab.crt`
(public, publish to repo). Never copy the `.key` to the repo server.

Generate an index keypair on the repo host:

```
buildctl key generate --name offline-lab-index --index --out ./keys/
```

Produces `offline-lab-index.key` (stays on repo host) and `offline-lab-index.crt`
(public, publish to repo alongside the build cert). The `--index` flag marks this
cert as an index-signing key; buildctl and appctl use this distinction to know which
cert verifies packages and which verifies the index.

---

## Key import on device

```
# HTTP or HTTPS repo
appctl repo add https://packages.offline-lab.com --name offline-lab

# USB or local filesystem repo
appctl repo add file:///mnt/usb/offline-lab-repo --name offline-lab
```

Fetches the root index, downloads both certs from `keys/`, verifies the index
signature against the index cert, stores both certs locally. All subsequent install
operations verify package signatures against the build cert. Index refreshes verify
against the index cert.

`appctl repo remove <name>` removes the repo and both stored certs. On key compromise,
remove and re-add the repo after the operator rotates the affected key.

---

## Multi-repo

Each repo has its own independent signing key. Users import keys per repo at
`appctl repo add` time. There is no central CA, no cross-signing, and no coordination
between repo operators. Any publisher can create a repo and signing key without
involving the appctl maintainers.

---

## Allowed protocols

HTTP, HTTPS, and `file://` are all permitted. This mirrors Debian's apt transport
model: transport confidentiality is provided by HTTPS when available, but content
integrity comes from the PKCS7 signatures regardless of transport. HTTP is safe for
offline and local network repos where HTTPS certificates are impractical, as long as
signing is in place. `file://` is required for USB and air-gapped repo use.

---

## Signature verification

### At install time (appctl)

appctl verifies the `.roothash.p7s` against the imported repo cert before writing
anything to disk:

```
openssl cms -verify -CAfile /data/config/keys/<hash>.crt \
    -in <name>.squashfs.roothash.p7s \
    -content <name>.squashfs.roothash
```

If verification fails, the install is aborted and no files are written.

### At runtime (dm-verity)

systemd mounts the squashfs via `RootImage=` and auto-discovers the companion files
by name. dm-verity verifies every block read against the hash tree. An image that has
been modified after install will fail to mount or cause read errors on tampered blocks.

This check happens in the kernel on every read from the squashfs. It cannot be
bypassed from userspace.

### At repo refresh (appctl)

`appctl repo refresh` re-downloads `index.json` and verifies `index.json.p7s` before
updating the local package cache. A tampered or unsigned index is rejected.

---

## Repository trust rules

**Same-server rule:** appctl rejects any package download URL that resolves to a
different server than the repo's `base_url`. A legitimate index cannot be used to
redirect downloads to a different server.

**No redirect following across origins:** if a repo server responds with an HTTP
redirect to a different origin or base URL, appctl rejects it. Redirects within the
same origin are permitted (e.g. HTTP → HTTPS on the same host).

**Single source of truth:** the `base_url` set at `appctl repo add` time is the
authoritative origin for that repo. Index and packages must come from that origin.

---

## Repo status and blocklist

Each repo entry in `packages.db` carries a `status` field:

| Status | Behaviour |
|---|---|
| `active` | Normal operation — refresh, install, update allowed |
| `paused` | No automatic refresh or updates; manual install still works |
| `blocked` | All operations rejected; installed packages from this repo still run |

`appctl repo pause <name>` and `appctl repo block <name>` manage this field.
A repo operator can optionally publish a signed blocklist via their index (future).

---

## What this model does not protect

**Physical access to removable storage:** these devices boot from SD cards or
removable NVMe. An attacker with physical access can remove the storage medium, modify
it on another machine, and return it. dm-verity and package signing protect against
software-level tampering and supply chain attacks; they do not protect against a
determined attacker with physical access to the storage.

A Secure Boot implementation for Pi exists, but it adds limited value here: even
with a verified boot chain, the storage is still removable and replaceable. This is
an accepted hardware boundary. RAUC bundle signing protects OTA update integrity
within this boundary.

**Root on the device:** a process running as root can call `portablectl attach`
directly without going through appctl, bypassing install-time verification. Root
access is assumed to be a fully compromised state.

**Key rotation latency:** if a signing key is compromised, already-installed packages
on devices will continue to pass dm-verity (the block hashes are still valid). Devices
must rotate the repo cert and update affected packages.

---

## Key rotation

When a repo operator needs to rotate their signing key, two approaches are available.

### Option A — Gradual rotation (recommended for large or offline-first repos)

1. Generate a new keypair: `buildctl key generate`
2. New packages published from this point are signed with the new key. Old packages
   keep their existing signatures — no re-download required.
3. Publish the new cert in the repo. Devices fetch it during the next `appctl repo refresh`.
4. `appctl repo add-key <name> <cert>` stores the new cert alongside the old one on device.
5. appctl verifies each package against the cert matching its `signing_key_id` field.
   Old packages verify against the old cert; new or updated packages verify against the
   new cert.
6. After 90 days (configurable, or manually), the old cert is pruned:
   `appctl repo remove-key <name> <key-id>`. Any package still signed with the old key
   must be updated before the old cert is removed.

This approach is safe for air-gapped and offline devices — they transition at their own
pace without forced re-downloads.

### Option B — Clean cut-over (for small repos or post-compromise)

1. Generate a new keypair.
2. Re-sign all packages: `buildctl rebuild --all` (see buildctl docs).
3. Bump the `key_rotation` counter in `index.json`.
4. `appctl repo refresh` detects the counter change and re-downloads and re-verifies
   all installed packages from that repo against the new cert.
5. Remove the old cert from the repo.

This is simpler for repos with few packages but requires devices to be reachable to
complete the rotation.

### Cert storage on device

```
/data/config/keys/<repo-hash>-<key-id>.crt   ← one file per key ID per repo
```

`signing_key_id` in the package metadata JSON carries the fingerprint of the key that
signed that package's `.roothash.p7s`. appctl looks up the matching cert file to run
verification. If no matching cert is found, install and reattach fail.

---

## Ideas

**Kernel keyring enforcement:** kernel-level p7s verification at every mount would
prevent even root from attaching unsigned images. Requires a CA baked into the kernel
and all repo keys cross-signed by it — incompatible with the open multi-publisher
model. Only relevant on x86 hardware with full Secure Boot. Not planned.
