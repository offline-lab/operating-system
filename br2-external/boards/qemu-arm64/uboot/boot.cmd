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
# Same logic as pi-zero-2w but for virtio block (vda) device names.
# Partition layout mirrors pi-zero-2w:
#   p1=boot(FAT) p2=extended p3=overlay p4=data
#   p5=kernel-a p6=rootfs-a p7=kernel-b p8=rootfs-b p9=bootstate

# Locate bootstate partition (p9) and set up raw block read/write
part start ${devtype} ${devnum} 9 dev_env
${devtype} dev ${devnum}

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

# QEMU virt passes a clean DTB with no GPU bootargs in /chosen.
# Move it to fdt_addr_r so we can resize it for initrd properties.
setenv fdt_org ${fdt_addr}
fdt addr ${fdt_org}
fdt get value bootargs_rpi /chosen bootargs
fdt move ${fdt_org} ${fdt_addr_r}
fdt addr ${fdt_addr_r}
fdt resize
setenv fdt_org ${fdt_addr_r}

# QEMU console is ttyAMA0 (PL011); apparmor enabled as on pi-zero-2w.
setenv bootargs_ol "console=ttyAMA0,115200 rootwait apparmor=1 security=apparmor systemd.machine_id=${MACHINE_ID} ${BOOT_CONDITION}"

# Slot partition mapping (virtio block → /dev/vda):
#   A: kernel=p5 rootfs=p6   B: kernel=p7 rootfs=p8
setenv bootargs
for BOOT_SLOT in "${BOOT_ORDER}"; do
  if test "x${bootargs}" != "x"; then
    # slot already selected
  elif test "x${BOOT_SLOT}" = "xA"; then
    if test ${BOOT_A_LEFT} -gt 0; then
      setexpr BOOT_A_LEFT ${BOOT_A_LEFT} - 1
      echo "Trying slot A, ${BOOT_A_LEFT} attempts remaining..."
      if load ${devtype} ${devnum}:5 ${kernel_addr_r} Image; then
          setenv bootargs "${bootargs_rpi} ${bootargs_ol} root=/dev/vda6 rootfstype=ext4 rauc.slot=A"
      fi
    fi
  elif test "x${BOOT_SLOT}" = "xB"; then
    if test ${BOOT_B_LEFT} -gt 0; then
      setexpr BOOT_B_LEFT ${BOOT_B_LEFT} - 1
      echo "Trying slot B, ${BOOT_B_LEFT} attempts remaining..."
      if load ${devtype} ${devnum}:7 ${kernel_addr_r} Image; then
          setenv bootargs "${bootargs_rpi} ${bootargs_ol} root=/dev/vda8 rootfstype=ext4 rauc.slot=B"
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
