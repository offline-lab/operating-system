# Offline Lab OS — Development Phases

## Phase 0: Bootable OS (current)

Minimal read-only microvisor that boots on Raspberry Pi Zero 2W.

### Goals
- Buildroot-based image built inside Docker on macOS or native arm64 buildbox
- 4-partition SD card: boot (FAT32) | rootfs-a (ext4, ro) | rootfs-b (empty) | data (rw)
- Initramfs sets up overlayfs (lower=rootfs-a, upper=/data/overlay)
- systemd init with networkd
- WiFi with DHCP, config provisioned from /boot/firmware → /data/config/wifi/
- SSH via dropbear with key-only auth, keys provisioned from /boot/firmware
- USB composite gadget: serial (ttyGS0) + ethernet (usb0)
- GPIO serial console on ttyS0 (mini UART)
- Data partition auto-expanded on first boot
- zram swap for low-memory operation
- Fake hardware clock for TLS before NTP
- Media-capable: Bluetooth, audio, GPU (64MB) all enabled
- No U-Boot — direct RPi bootloader
- Modular package split: offlinelab-{base,usb-gadget,wifi,ssh,zram}

### Trade-offs
- Shared kernel across A/B slots — kernel update affects both until Phase 1
- No automatic rollback — broken rootfs requires manual SD card intervention
- No splash screen — just kernel console output until Phase 1 (psplash)
- Persistent overlay upper on /data — stale overlay can conflict after rootfs update
- Config provisioning is first-boot-only — to re-provision, delete persistent copy

---

## Phase 0.5: Kernel trimming

Strip the stock `bcm2711_defconfig` down to what the Pi Zero 2W actually needs.
See [KERNEL.md](KERNEL.md) for detailed analysis and implementation plan.
Tasks tracked at https://github.com/orgs/offline-lab/projects/3

### Goals
- Expanded kernel fragment that disables unused driver categories
- Drop ~1800 unnecessary options (3814 → ~2000)
- Reduce module directory from ~100MB to ~30MB
- Faster builds (~30-40% reduction)
- Lower kernel RAM overhead (~10-15MB freed on 512MB device)

### What gets disabled
- 85 network vendor drivers (keep only Broadcom)
- All WLAN vendors except Broadcom (brcmfmac)
- 30+ audio hat drivers (HiFiBerry, IQAudio, JustBoom)
- Pi 4/5 hardware (V3D, BCM2711 thermal, BCM2712, PCIe)
- Non-Broadcom Bluetooth drivers
- Unused buses (CAN, NFC, ATA/SATA, SCSI, Gameport)
- Unused filesystems (ReiserFS, JFS, XFS, GFS2, Btrfs, Bcachefs, NFS, CEPH, etc.)
- ~100 unused crypto algorithms
- DVB/media capture drivers we don't need
- All DRM panel drivers, USB display drivers

### Approach
1. Boot the Phase 0 image, capture `lsmod` and `/proc/config.gz`
2. Build expanded fragment file disabling categories
3. Verify boot, WiFi, BT, USB gadget, audio, HDMI still work
4. Iterate: if something breaks, re-enable selectively

### Trade-offs
- Fragment approach means merge ordering matters — fragment runs after defconfig
- Some disabled options may have unexpected dependencies; need to test each category
- Still carrying bcm2711_defconfig as base (full custom defconfig is Phase 1)

---

## Phase 1: Updates + polish

A/B rootfs switching, boot splash, and custom kernel defconfig.

### Goals
- Initramfs reads slot marker from /boot/firmware to select rootfs-a or rootfs-b
- Boot counter with automatic fallback (3 failures → switch to other slot)
- RAUC integration (or custom update mechanism) for OTA-style updates
- psplash boot splash screen
- Per-slot overlay directories (/data/overlay/a/ and /data/overlay/b/)
- Per-slot kernel support via tryboot or initramfs kernel loading
- Full custom kernel defconfig replacing bcm2711_defconfig + fragments
- Power-saving kernel patches (CPU idle, suspend-to-RAM, USB autosuspend, tickless)

### Kernel defconfig (from Phase 0.5 trimmed config)
1. Take trimmed `.config`, run `make savedefconfig`
2. Store as `br2-external/configs/offlinelab_pi_zero_2w_defconfig` (replaces current)
3. Remove kernel fragment file — everything in defconfig
4. Target: ~1200 options, ~15MB module directory, 50-60% faster builds

### Power-saving patches
- CPU frequency: schedutil governor with aggressive downscaling
- `CONFIG_CPU_IDLE` + `CONFIG_ARM_CPUIDLE` (C-states for Cortex-A53)
- `CONFIG_SUSPEND` + `CONFIG_PM` for system suspend-to-RAM
- USB autosuspend when gadget not connected
- Runtime PM for unused peripherals (HDMI, I2C, SPI)
- `CONFIG_NO_HZ_FULL` tickless idle
- Patch location: `br2-external/boards/pi-zero-2w/patches/linux/`

### Trade-offs
- tryboot mechanism may not work reliably on Pi Zero 2W (bootcode.bin, not EEPROM)
- RAUC adds complexity but provides proven update framework
- Custom defconfig requires manual updates when switching kernel versions
- Power-saving patches require ongoing maintenance against upstream RPi fork

### Open questions
- Use tryboot conditional in config.txt or pure initramfs-based slot selection?
- RAUC vs custom update scripts?
- Which power-saving patches are worth the maintenance cost?

---

## Phase 2: Discovery + network services

Service discovery, name resolution, and time synchronization via
[disco](https://github.com/offline-lab/disco) — our custom lightweight daemon
for offline/airgapped networks.

### Goals
- **disco-daemon**: UDP broadcast discovery (port 5354), automatic peer detection
- **libnss_disco.so.2**: NSS module for native hostname resolution
  (`getaddrinfo("web1")` resolves via disco without DNS)
- **disco CLI**: host/service listing, lookup, status, time management
- **Time sync**: GPS-based clock discipline via `adjtimex(2)`, multi-source validation
  (complements fake-hwclock: cold boot → fake-hwclock → network up → disco time sync)
- **Service detection**: automatic port scanning for known services on discovered peers
- **Optional DNS server**: `.disco` domain for legacy clients
- Config stored at `/data/config/disco/config.yaml` (provisioning pattern)
- disco user/group with minimal capabilities (CAP_NET_RAW, CAP_NET_BIND_SERVICE, CAP_SYS_TIME)
- nsswitch.conf: `hosts: files disco dns`

### Package: offlinelab-disco
- Builds disco-daemon, disco CLI, libnss_disco.so.2 from source
- Requires Go toolchain (host-go) for cross-compilation
- NSS module is pure C (no external dependencies)
- Binary footprint: ~12MB (daemon 5.8MB + CLI 3.6MB + NSS <1MB)
- Runtime: <10MB RAM, <5% CPU idle

### Architecture
```
Boot sequence:
  fake-hwclock (restore last-known time)
    → WiFi/network up (TLS works because clock is recent)
      → disco-daemon starts (discovers peers, broadcasts self)
        → disco time sync corrects clock from GPS sources
          → fake-hwclock saves corrected time on shutdown
```

### Trade-offs
- Go toolchain adds ~10min to first build and ~500MB to build cache
- NSS module requires glibc (already used, but rules out musl)
- Broadcast-only: no routing between subnets (single broadcast domain)
- GPS broadcaster hardware optional — time sync degrades gracefully without it

### Open questions
- disco-gps-broadcaster: include in image or only for dedicated GPS nodes?
- Default config: enable DNS server on port 53 or leave disabled?
- Security: enable HMAC signing by default or leave optional?
- Captive portal or landing page: portable service or built into disco?

---

## Phase 3: Portable services & extensions

Systemd portable service, sysext/confext, and security infrastructure.
App images stored on `/data/apps/` as squashfs.

### Phase 3.1: Enable portabled + sysext + confext (DONE)
- `BR2_PACKAGE_SYSTEMD_PORTABLED=y`, `BR2_PACKAGE_SYSTEMD_SYSEXT=y`
- New package `offlinelab-portable`: symlinks to /data/{apps,extensions,confexts},
  modules-load.d for squashfs+loop
- First-boot provisioning creates `/data/apps/`, `/data/extensions/`, `/data/confexts/`

### Phase 3.2: dm-verity + AppArmor (DONE)
- `CONFIG_DM_VERITY=m` with `CONFIG_DM_VERITY_VERIFY_ROOTHASH_SIG=y`
- `BR2_PACKAGE_APPARMOR=y` + binutils (parser, aa-enabled, aa-exec)
- `CONFIG_LSM="apparmor"`, `apparmor=1 security=apparmor` in cmdline
- No cryptsetup on target — `veritysetup` is build-host/CLI-tool only

### Phase 3.3: Hello-world test + profiles + hardening (DONE)
- Hello-world portable service (squashfs, test-only) on data partition
- Default portable profile: `ProtectSystem=strict`, `NoNewPrivileges=yes`,
  `MemoryMax=128M`, `CPUQuota=50%`
- `admin` user has full sudo (covers portablectl/sysext/confext)

### Architecture
- Portable images: squashfs on `/data/apps/`, symlinked from `/var/lib/portables`
- System extensions: overlay `/usr/` from `/data/extensions/`
- Config extensions: overlay `/etc/` from `/data/confexts/`
- dm-verity: kernel verifies image integrity, root hash signed with project key
- AppArmor: portable services can ship their own profiles
- Portabled/sysextd are D-Bus socket-activated (zero idle cost)
- Overlayfs caveat: attached services are per-slot (A/B), images persist across slots

### Future (separate repo)
- CLI wrapper around portablectl for app management
- Image signing workflow with dm-verity
- USB drive import/export
- Service manifest format, dependencies, lifecycle

---

## Future: Additional hardware

### Goals
- Support for other SBCs (Pi 4, Pi 5, other ARM boards)
- New board = new `boards/<name>/` directory + new defconfig
- Shared offlinelab-base package across all boards
- Board-specific packages for hardware-specific config

### Open questions
- Which boards are worth supporting?
- How to handle boards with different bootloaders (U-Boot, UEFI)?
- How to handle boards with different partition schemes (GPT vs MBR)?
