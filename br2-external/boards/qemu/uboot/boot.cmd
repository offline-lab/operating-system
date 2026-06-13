################################################################################
#         ____  ___________               __          __                       #
#        / __ \/ __/ __/ (_)___  ___     / /   ____ _/ /_                      #
#       / / / / /_/ /_/ / / __ \/ _ \   / /   / __ `/ __ \                     #
#      / /_/ / __/ __/ / / / / /  __/  / /___/ /_/ / /_/ /                     #
#      \____/_/ /_/ /_/_/_/ /_/\___/  /_____/\__,_/_.___/                      #
#                                                                              #
#      Copyright (C) 2025-2026 Offline Lab                                     #
#      Contact: info@offline-lab.com                                           #
#      SPDX-License-Identifier: AGPL-3.0-only                                  #
################################################################################

# Offline Lab OS — QEMU arm64 A/B boot script
# Partition layout (virtio block → /dev/vda):
#   p1=boot(FAT) p2=kernel-a p3=rootfs-a p4=kernel-b p5=rootfs-b p6=bootstate p7=overlay p8=data

# virtio block device — always virtio 0 on QEMU virt machine
setenv devtype virtio
setenv devnum 0

# Read bootstate from p6 (raw block read/write, 32 sectors = 16KB)
part start ${devtype} ${devnum} 6 dev_env

setenv loadbootstate " \
    echo 'Loading bootstate...'; \
    ${devtype} read ${scriptaddr} ${dev_env} 0x20; \
    env import -c ${scriptaddr} 0x4000;"

setenv storebootstate " \
    echo 'Saving bootstate...'; \
    env export -c -s 0x4000 ${scriptaddr} BOOT_ORDER BOOT_A_LEFT BOOT_B_LEFT MACHINE_ID; \
    ${devtype} write ${scriptaddr} ${dev_env} 0x20;"

run loadbootstate
test -n "${BOOT_ORDER}" || setenv BOOT_ORDER "A B"
test -n "${BOOT_A_LEFT}" || setenv BOOT_A_LEFT 3
test -n "${BOOT_B_LEFT}" || setenv BOOT_B_LEFT 3

# ConditionFirstBoot= support
test -n "${MACHINE_ID}" || setenv BOOT_CONDITION "systemd.condition-first-boot=true"

# QEMU virt: use the DTB QEMU passed to U-Boot (stored in fdtcontroladdr).
# No RPi firmware bootargs to extract — /chosen/bootargs is empty on virt.
setenv fdt_org ${fdtcontroladdr}
fdt addr ${fdt_org}
fdt resize 0x1000

# QEMU console is ttyAMA0 (PL011); apparmor enabled as on pi-zero-2w.
setenv bootargs_ol "console=ttyAMA0,115200 rootwait apparmor=1 security=apparmor systemd.machine_id=${MACHINE_ID} ${BOOT_CONDITION}"

# Slot selection
setenv bootargs
for BOOT_SLOT in "${BOOT_ORDER}"; do
  if test "x${bootargs}" != "x"; then
    # slot already selected
  elif test "x${BOOT_SLOT}" = "xA"; then
    if test ${BOOT_A_LEFT} -gt 0; then
      setexpr BOOT_A_LEFT ${BOOT_A_LEFT} - 1
      echo "Trying slot A, ${BOOT_A_LEFT} attempts remaining..."
      if load ${devtype} ${devnum}:2 ${kernel_addr_r} Image; then
          setenv bootargs "${bootargs_ol} root=/dev/vda3 rootfstype=ext4 rauc.slot=A"
      fi
    fi
  elif test "x${BOOT_SLOT}" = "xB"; then
    if test ${BOOT_B_LEFT} -gt 0; then
      setexpr BOOT_B_LEFT ${BOOT_B_LEFT} - 1
      echo "Trying slot B, ${BOOT_B_LEFT} attempts remaining..."
      if load ${devtype} ${devnum}:4 ${kernel_addr_r} Image; then
          setenv bootargs "${bootargs_ol} root=/dev/vda5 rootfstype=ext4 rauc.slot=B"
      fi
    fi
  fi
done

if test -n "${bootargs}"; then
  if load ${devtype} ${devnum}:1 ${ramdisk_addr_r} initramfs.cpio.gz; then
    setenv initrd_size ${filesize}
  else
    echo "Failed to load initramfs!"
    reset
  fi

  run storebootstate

  echo "Booting Offline Lab OS (QEMU)..."
  booti ${kernel_addr_r} ${ramdisk_addr_r}:${initrd_size} ${fdt_org}
fi

echo "No valid slot found, resetting counters..."
setenv BOOT_A_LEFT 3
setenv BOOT_B_LEFT 3
run storebootstate
reset
