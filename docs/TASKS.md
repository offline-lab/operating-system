# Phase 0 Tasks

## Build infrastructure
- [x] Dockerfile (adapt from reference)
- [x] .packages.list (trimmed builder dependencies)
- [x] bin/builder.sh — Docker build environment (moved from root)
- [x] bin/buildbox.sh — native arm64 VM build pipeline
- [x] bin/build.sh, bin/build-native.sh
- [x] bin/clean.sh
- [x] bin/verify.sh — automated image verification (118 checks)
- [x] env.example, config.example
- [x] .gitignore, .dockerignore
- [x] Skeleton merged-usr symlinks (bin, lib, sbin → usr/*)

## Buildroot external tree
- [x] br2-external/external.desc (OFFLINELAB)
- [x] br2-external/external.mk
- [x] br2-external/Config.in
- [x] br2-external/users.txt (app user, password=offlinelab, groups incl. netdev)
- [x] br2-external/devices.txt

## Skeleton
- [x] br2-external/skeleton/etc/passwd (root shell /bin/bash, not /bin/sh)
- [x] br2-external/skeleton/etc/group (sudo, bluetooth, audio, video, netdev)
- [x] br2-external/skeleton/etc/shadow
- [x] br2-external/skeleton/etc/profile (hardcoded PATH, colored PS1)
- [x] br2-external/skeleton/etc/profile.d/umask.sh
- [x] br2-external/skeleton/etc/hosts
- [x] br2-external/skeleton/etc/resolv.conf
- [x] br2-external/skeleton/etc/protocols
- [x] br2-external/skeleton/etc/services

## Board support
- [x] br2-external/configs/offlinelab_pi_zero_2w_defconfig
- [x] br2-external/boards/pi-zero-2w/config.txt (dwc2 dr_mode=otg)
- [x] br2-external/boards/pi-zero-2w/cmdline.txt (fbcon=nodefer, usbcore.autosuspend=-1)
- [x] br2-external/boards/pi-zero-2w/genimage.cfg.in
- [x] br2-external/boards/pi-zero-2w/post-build.sh
- [x] br2-external/boards/pi-zero-2w/post-image.sh
- [x] br2-external/boards/pi-zero-2w/initramfs/init
- [x] br2-external/boards/pi-zero-2w/fragments/kernel-fragment.config (overlayfs, USB gadget+HID, zram, DWC2 dual-role)
- [x] br2-external/boards/pi-zero-2w/fragments/busybox-fragment.config (CONFIG_STATIC=y)

## offlinelab-base package
- [x] Config.in, offlinelab-base.mk
- [x] boot-firmware.mount (After=dev-mmcblk0p1.device), expand-data.service, expand-data.sh
- [x] fake-hwclock.service, fake-hwclock.sh
- [x] serial-getty@ttyS0, getty@tty1, /etc/issue (with IP addresses)
- [x] /data/config directory creation + app user .bashrc in expand-data.sh

## offlinelab-usb-gadget package
- [x] Config.in, offlinelab-usb-gadget.mk
- [x] usb-gadget.service, usb-gadget.sh (skips when USB devices connected)
- [x] usb0.network (DHCPServer, 10.55.0.1/24), serial-getty@ttyGS0
- [x] 99-offlinelab-usb-gadget.conf (configfs, dwc2, libcomposite)

## offlinelab-wifi package
- [x] Config.in, offlinelab-wifi.mk
- [x] provision-wifi.service, provision-wifi.sh (boot → /data/config provisioning)
- [x] wifi-setup.service (BindsTo=wlan0.device), wifi-setup.sh
- [x] wlan0.network, 02w-wifi-fix.conf
- [x] Build-time WiFi config (BR2_PACKAGE_OFFLINELAB_WIFI_WPA_*)
- [x] wpa_cli + ctrl_interface enabled (BR2_PACKAGE_WPA_SUPPLICANT_CLI=y)

## offlinelab-ssh package
- [x] Config.in, offlinelab-ssh.mk
- [x] provision-ssh.service, provision-ssh.sh (host key gen + authorized_keys provisioning)
- [x] dropbear.service (key-only auth, Requires=provision-ssh, persistent host keys)
- [x] Build-time authorized_keys (BR2_PACKAGE_OFFLINELAB_SSH_CREATE_AUTHORIZED_KEYS_*)

## offlinelab-zram package
- [x] Config.in, offlinelab-zram.mk
- [x] zram-swap.service, zram-swap.sh, zram-swap.config
- [x] 99-offlinelab-zram.conf

## Rootfs overlay
- [x] br2-external/rootfs_overlay/etc/fstab
- [x] br2-external/rootfs_overlay/etc/hostname
- [x] br2-external/rootfs_overlay/etc/hosts
- [x] br2-external/rootfs_overlay/etc/bash.bashrc (PS1 + aliases)
- [x] br2-external/rootfs_overlay/etc/os-release (PRETTY_NAME="Offline Lab OS")
- [x] br2-external/rootfs_overlay/etc/modprobe.d/02w-wifi-fix.conf
- [x] br2-external/rootfs_overlay/etc/sysctl.d/99-offlinelab.conf
- [x] br2-external/rootfs_overlay/etc/sudoers.d/app
- [x] br2-external/rootfs_overlay/root/.bashrc (sources /etc/bash.bashrc)

## Defconfig highlights
- BR2_PACKAGE_XZ=y — target liblzma so kmod can decompress .ko.xz modules at runtime
- BR2_PACKAGE_HOST_KMOD_XZ=y — host depmod can index .ko.xz modules at build time
- BR2_PACKAGE_WPA_SUPPLICANT_CLI=y — wpa_cli + CONFIG_CTRL_IFACE for runtime WiFi management
- BR2_PACKAGE_HAVEGED removed — BCM2835 hardware RNG (CONFIG_HW_RANDOM_BCM2835=y) is built-in

## Build verification (automated — bin/verify.sh, 137 checks)
- [x] Artifact files: rootfs.ext4, initramfs.cpio.gz, Image, sdcard.img
- [x] SD card: 4 partitions, correct types, boot flag
- [x] Boot partition: kernel, initramfs, config.txt, DTBs, rpi-firmware
- [x] Initramfs: static busybox, init with overlayfs/mdev/switch_root
- [x] Rootfs: systemd, bash, dropbear, all units + scripts installed and enabled
- [x] Network: wlan0.network, usb0.network with DHCPServer
- [x] Modules: modules.dep populated, target kmod +XZ, liblzma present
- [x] Kernel: overlayfs, initramfs, USB DWC2+gadget+HID, zram, MMC built-in
- [x] System: app user uid 1000, netdev group, merged-usr, machine-id uninitialized
- [x] Shell: bash.bashrc, root .bashrc, /etc/profile valid PATH
- [x] Systemd deps: boot-firmware.mount device unit, dropbear Requires=provision-ssh

## Boot fixes applied
- [x] PATH in /etc/profile — custom skeleton doesn't substitute `@PATH@`
- [x] Root shell /bin/bash — bash invoked as /bin/sh runs POSIX mode, ignores .bashrc
- [x] Per-user .bashrc — buildroot bash compiled without SYS_BASHRC, /etc/bash.bashrc never auto-sourced
- [x] HDMI console — getty@tty1 enabled
- [x] USB keyboard — dr_mode=otg + USB_HID + HID_GENERIC kernel config
- [x] USB gadget coexistence — usb-gadget.sh detects keyboard in sysfs, stays in host mode
- [x] USB autosuspend — disabled via cmdline (usbcore.autosuspend=-1)
- [x] Cold-boot display — fbcon=nodefer in cmdline
- [x] WiFi ctrl_interface — needs CONFIG_CTRL_IFACE compiled in (BR2_PACKAGE_WPA_SUPPLICANT_CLI=y)
- [x] WiFi timing — BindsTo=sys-subsystem-net-devices-wlan0.device
- [x] WiFi country — configurable via BR2_PACKAGE_OFFLINELAB_WIFI_WPA_COUNTRY (default "00")
- [x] Target kmod XZ — BR2_PACKAGE_XZ=y so modprobe can decompress .ko.xz at runtime
- [x] Host depmod XZ — BR2_PACKAGE_HOST_KMOD_XZ=y so depmod indexes .ko.xz at build time
- [x] zram — CONFIG_ZRAM=m + LZ4 crypto in kernel fragment
- [x] IP addresses on login screen (agetty \4{wlan0}, \4{usb0})
- [x] app user password (=offlinelab in users.txt)
- [x] boot-firmware.mount — After=dev-mmcblk0p1.device (correct systemd device unit)
- [x] dropbear.service — Requires=provision-ssh (hard dep, no restart loop without host key)
- [x] os-release — PRETTY_NAME="Offline Lab OS" (was "Buildroot 2026.05-git")
- [x] Removed haveged — BCM2835 hardware RNG built-in, kernel 6.12 CSPRNG sufficient

## Hardware verification (complete)
- [x] Boot on Pi Zero 2W — HDMI console with USB keyboard
- [x] Keyboard works for login (app/offlinelab)
- [x] zram swap active (confirmed working after target kmod XZ fix)
- [x] wlan0 interface present (confirmed after target kmod XZ fix)
- [x] Data partition expanded on first boot (resize2fs confirmed)
- [x] First-boot display (works)
- [x] WiFi connects with provisioned config
- [x] PS1 changes on sudo su, os-release shows "Offline Lab OS"
- [x] Overlayfs persistence across reboot (confirmed — device boots clean, no errors)
- [x] SSH via dropbear with key-only auth
- [x] SSH host keys persist across reboot (/data/config/ssh/dropbear/)
- [x] USB composite gadget works (serial ttyGS0 + ethernet usb0) — without keyboard
- [x] /data/config directory structure + app .bashrc created
- [x] fake-hwclock restores time on boot (confirmed — device boots clean, no errors)
- [x] systemctl --failed shows nothing
- [x] wpa_cli -i wlan0 status works (fixed: /var/run → ../run symlink in skeleton + post-build.sh)

## Repo organization
- [x] Moved builder.sh to bin/
- [x] Moved vm/ cloud-init to bin/buildbox/cloud-init/
- [x] Moved PHASES.md, TASKS.md, KERNEL.md to docs/
- [x] Updated .gitignore (.ssh/, artifacts/, .config, .env, IDE files)
- [x] Updated .dockerignore
- [x] Updated README.md with repo layout, no-binaries policy, corrected paths

---

# Phase 0.5 Tasks — Kernel Trimming

See [KERNEL.md](KERNEL.md) for full analysis.

## Data collection
- [x] Boot Phase 0 image, capture `lsmod` output (50 modules)
- [x] Save running config via `/proc/config.gz` (3798 options)
- [x] Document which modules are actually loaded at runtime

## Kernel fragment expansion (212 disable lines added)
- [x] Disable all NET_VENDOR_* except Broadcom (71 disabled)
- [x] Disable all WLAN_VENDOR_* except Broadcom (17 disabled)
- [x] Disable all SND_BCM2708_SOC_* hat drivers (33 disabled)
- [x] Disable all DRM_PANEL_*/DRM_BRIDGE_* drivers (23 disabled)
- [x] Disable non-Broadcom Bluetooth drivers (11 disabled)
- [x] Disable Pi 4/5 hardware (DRM_V3D, BCM2711_THERMAL, BCM2712_*, PCIE_BRCMSTB)
- [x] Disable unused buses (CAN, NFC, ATA, GAMEPORT, SCSI as module)
- [x] Disable unused filesystems (21 disabled)
- [x] Disable unused crypto algorithms (9 disabled)
- [x] Disable DRM_GUD, DRM_UDL, DRM_SSD130X, DVB_CORE, MEDIA_USB_SUPPORT
- [x] Disable KVM/VIRTUALIZATION, enterprise networking (16 disabled)

## Verification
- [x] Build completes with expanded fragment
- [x] bin/verify.sh passes (118/118)
- [x] Boot on hardware — WiFi, USB gadget, HDMI all work
- [x] Module directory: ~100MB → 17MB (-83%, exceeded 30MB target)
- [x] Image size: 67MB → 55MB (-18%)
- [x] Options: 3798 → 2989 (-21%)

---

# Phase 2 Tasks — disco integration

disco source lives at github.com/offline-lab/disco (separate repo). The offlinelab-disco
package fetches and cross-compiles it at build time — no source or binaries stored in
br2-builder.

## offlinelab-disco package
- [ ] Verify host-go / golang-package support in buildroot fork
- [ ] Create offlinelab-disco/Config.in (select host-go, options for DNS/GPS/signing)
- [ ] Create offlinelab-disco/offlinelab-disco.mk (golang-package or custom, fetch from github)
- [ ] disco-daemon.service (systemd, After=network-online.target, capabilities)
- [ ] disco user/group creation (users.txt or package postinst)
- [ ] Default config.yaml at /data/config/disco/config.yaml (provisioning pattern)
- [ ] provision-disco.sh (first-boot config provisioning from /boot/firmware/disco.yaml)
- [ ] Install libnss_disco.so.2 to /lib/ with symlinks
- [ ] Update /etc/nsswitch.conf: hosts: files disco dns
- [ ] Update kernel fragment if needed (UDP broadcast, NET_RAW capability)
- [ ] Update bin/verify.sh for disco checks
- [ ] Test: multi-node discovery on local network
- [ ] Test: hostname resolution via NSS (`getent hosts <peer>`)
- [ ] Test: disco CLI commands (hosts, services, lookup, status)

## disco-gps-broadcaster (optional, hardware-dependent)
- [ ] Decide: include in base image or separate package?
- [ ] disco-gps-broadcaster.service (if included)
- [ ] GPS serial device configuration (/dev/ttyACM0)

## Time sync integration
- [ ] Enable time_sync in default config.yaml
- [ ] Verify fake-hwclock → disco time sync handoff on boot
- [ ] Test: clock correction from GPS time source
- [ ] Test: multi-source validation (min_sources: 2)

---

# Phase 1 Tasks — U-Boot + A/B Updates + Polish

Architecture: U-Boot bootloader + RAUC A/B updates, modeled on Home Assistant OS.
Boot chain: `bootcode.bin → start.elf → u-boot.bin → boot.scr → kernel from slot A or B`
Partition layout: boot(32M) + kernel-a(24M sqfs) + rootfs-a(512M ext4) + kernel-b + rootfs-b + bootstate(8M raw) + overlay(96M ext4) + data(64M ext4)
Full plan: `.claude/plans/frolicking-chasing-micali.md`

## Step 1: Custom kernel defconfig
- [x] Save running config from Pi (`/tmp/config.gz`)
- [x] Store as `br2-external/boards/pi-zero-2w/configs/linux.config` (full config, savedefconfig later)
- [x] Switch defconfig to `BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG` (remove fragment approach)
- [x] Build + verify boots identically to Phase 0.5

## Step 2: U-Boot integration (single slot, no A/B)
- [x] Add U-Boot to defconfig (`BR2_TARGET_UBOOT=y`, `rpi_arm64` defconfig)
- [x] Create U-Boot fragment (`fragments/uboot-fragment.config` — squashfs+LZO)
- [x] Create boot.cmd — single-slot, preserves firmware DTB, loads kernel from sqfs p5
- [x] Update config.txt: `kernel=u-boot.bin`, `disable_splash=1`
- [x] New partition layout in genimage.cfg.in (MBR extended, 9 partitions)
- [x] Update post-image.sh: compile boot.scr, build kernel-a.img sqfs, overlay.ext4
- [x] Update initramfs/init: new partition numbers, rauc.slot parsing, overlay partition
- [x] Update expand-data.sh: remove overlay dir creation (now on overlay partition)
- [x] Update verify.sh: new partition checks, u-boot.bin/boot.scr assertions
- [x] Added host-uboot-tools, host-squashfs to defconfig
- [x] Build completes (131/131 verify)
- [x] Verification passes
- [x] Hardware: U-Boot banner on UART, kernel loads, system boots

## Step 3: A/B boot logic
- [x] Full A/B bootchooser in boot.cmd (model on HAOS `uboot-boot64.ush`)
- [x] Initramfs: parse `rauc.slot=A|B`, per-slot overlay dirs (already done in Step 2)
- [x] Bootstate: p9 starts empty, U-Boot initializes defaults on first boot (no mkenvimage needed)
- [x] Update verify.sh: boot.scr A/B assertions (BOOT_ORDER, counters, rauc.slot, storebootstate)
- [x] Build completes (137/137 verify)
- [x] Hardware: boot.cmd A/B logic confirmed working (rauc.slot=A, initramfs+overlayfs boot)

## Step 4: RAUC
- [x] RAUC PKI created (`.rauc/` — ca.cert.pem, signing.cert.pem, signing.key, signing.csr; gitignored)
- [ ] Create `offlinelab-update` package (Config.in, .mk)
- [ ] RAUC system.conf, keyring (bake ca.cert.pem into image), fw_env.config
- [ ] rauc-mark-good.service (marks slot good after successful boot)
- [ ] Update post-image.sh: build RAUC bundle
- [ ] Update bin/verify.sh: RAUC + A/B checks
- [ ] Verify: `rauc status` shows slots, `rauc install` updates inactive slot

## Step 5: psplash
- [ ] Add psplash to defconfig
- [ ] Create splash image SVG and add it in the repo
- [ ] Create script to generate a splash image in PNG from the SVG file in the repo
- [ ] Add png in build process on the correct location
- [ ] psplash.service (early systemd) + psplash-quit.service (after multi-user)

## Step 6: USB update workflow
- [ ] udev rule for USB drive detection
- [ ] usb-update.sh + usb-update.service
- [ ] LED feedback during update

## Power-saving (deferred — separate phase)
- [ ] CPU frequency governor tuning
- [ ] CONFIG_CPU_IDLE + CONFIG_ARM_CPUIDLE
- [ ] CONFIG_SUSPEND + CONFIG_PM
- [ ] USB autosuspend when gadget not connected
- [ ] CONFIG_NO_HZ_FULL tickless idle
- [ ] Measure power consumption before/after


## License

- [ ] Update the license in the repo to what we discussed, I think it was AGPL

- [ ] Add the license banner to all applicable files (as in don't do it if it
  breaks adding this header, like in binary files and files that don't consider
  `#` as a comment, but ideally in every config file on the filesystem that we can add it to).
      banner:

################################################################################
#         ____  ___________               __          __                       #
#        / __ \/ __/ __/ (_)___  ___     / /   ____ _/ /_                      #
#       / / / / /_/ /_/ / / __ \/ _ \   / /   / __ `/ __ \                     #
#      / /_/ / __/ __/ / / / / /  __/  / /___/ /_/ / /_/ /                     #
#      \____/_/ /_/ /_/_/_/ /_/\___/  /_____/\__,_/_.___/                      #
#                                                                              #
#      Copyright (C) 2025-2026 Offline Lab                                     #
#      Contact: info@offline-lab.com                                           #
#                                                                              #
#      SPDX-License-Identifier: <LICENSE HERE>                                 #
#                                                                              #
################################################################################








---

# Future Work — Other Repos

## CLI tool (new repo: offline-lab/ol-cli or similar)
- [ ] Runtime power profile management (performance vs battery)
- [ ] Display/screen configuration
- [ ] Service management (install, start, stop portable services)
- [ ] Network diagnostics
- [ ] System status dashboard

## Portable service images (new repo: offline-lab/ol-services or similar)
- [ ] MP3 player with on-screen display
- [ ] Minimized/optimized video player
- [ ] Non-media services (serial, bluetooth, custom protocols)
- [ ] Service manifest format (dependencies, config.txt requirements, resource limits)
- [ ] Build tooling for squashfs portable service images

## Design constraints
- systemd-networkd only — no NetworkManager, no dnsmasq, no connman
- Maximum flexibility: OS must support media apps (audio, video, screen), serial devices, bluetooth, and headless services
- Power optimization deferred — get it working first, optimize later via CLI tool
- No binaries or third-party source in git — everything fetched at build time
- All work must be documented for agent handoff
