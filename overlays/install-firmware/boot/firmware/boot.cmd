if test -z "${boot_slot}"; then
    setenv boot_slot a
    setenv boot_tries 3
    saveenv
fi

if test -n "${boot_pending}"; then
    if test ${boot_tries} -gt 0; then
        setexpr boot_tries ${boot_tries} - 1
        saveenv
    else
        if test "${boot_slot}" = "a"; then
            setenv boot_slot b
        else
            setenv boot_slot a
        fi
        setenv boot_tries 3
        setenv boot_pending
        saveenv
    fi
fi

if test "${boot_slot}" = "a"; then
    setenv bootpart 3
else
    setenv bootpart 4
fi

load mmc 0:1 ${kernel_addr_r}  /vmlinuz
load mmc 0:1 ${ramdisk_addr_r} /initrd.img

setenv ramdisk_size ${filesize}
setenv bootargs "dwc_otg.lpm_enable=0 console=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p${bootpart} rootfstype=squashfs ro boot_slot=${boot_slot} rootwait modules-load=dwc2 cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 apparmor=1 security=apparmor systemd.restore_state=0 rfkill.default_state=1"

booti ${kernel_addr_r} ${ramdisk_addr_r}:${ramdisk_size} ${fdt_addr}
