# Offline Lab OS boot script — single slot (Step 2)
# Step 3 adds A/B slot selection with bootstate

# Preserve RPi firmware device tree (includes overlays applied by config.txt)
setenv fdt_org ${fdt_addr}
fdt addr ${fdt_org}
fdt get value bootargs_rpi /chosen bootargs

setenv bootargs "${bootargs_rpi} rootwait rauc.slot=A"

# Load kernel from kernel-a partition (squashfs, partition 5)
echo "Loading kernel from slot A..."
if load ${devtype} ${devnum}:5 ${kernel_addr_r} Image; then
    echo "Loading initramfs..."
    if load ${devtype} ${devnum}:1 ${ramdisk_addr_r} initramfs.cpio.gz; then
        setenv initrd_size ${filesize}
        # Prevent U-Boot from relocating the firmware DTB
        setenv fdt_addr
        echo "Booting Offline Lab OS..."
        booti ${kernel_addr_r} ${ramdisk_addr_r}:${initrd_size} ${fdt_org}
    fi
fi

echo "Boot failed!"
reset
