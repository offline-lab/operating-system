#!/usr/bin/env bash
set -e -u -o pipefail

# If USB devices are connected (keyboard, mouse, etc.), the port is in host
# mode and we must not switch it to gadget mode — that would kill the device.
if ls /sys/bus/usb/devices/[0-9]*/product &>/dev/null; then
    echo "usb-gadget: USB device(s) connected, staying in host mode"
    exit 0
fi

udc="$(ls /sys/class/udc 2>/dev/null || true)"
if [[ -z "${udc}" ]]; then
    echo "usb-gadget: no UDC available, skipping"
    exit 0
fi

cd /sys/kernel/config/usb_gadget/
mkdir -p offlinelab
cd offlinelab

echo 0x1d6b >idVendor  # Linux Foundation
echo 0x0104 >idProduct # Multifunction Composite Gadget
echo 0x0100 >bcdDevice # v1.0.0
echo 0x0200 >bcdUSB    # USB2

echo 0xEF >bDeviceClass
echo 0x02 >bDeviceSubClass
echo 0x01 >bDeviceProtocol

mkdir -p strings/0x409
echo "offlinelab0001"         >strings/0x409/serialnumber
echo "Offline Lab"            >strings/0x409/manufacturer
echo "Offline Lab USB Device" >strings/0x409/product

mkdir -p configs/c.1/strings/0x409
echo "ACM+ECM" >configs/c.1/strings/0x409/configuration
echo 250       >configs/c.1/MaxPower
echo 0x80      >configs/c.1/bmAttributes

# ACM serial (ttyGS0)
mkdir -p functions/acm.usb0
ln -sf functions/acm.usb0 configs/c.1/

# ECM ethernet (usb0)
mkdir -p functions/ecm.usb0
echo "00:dc:c8:f7:75:15" >functions/ecm.usb0/host_addr
echo "00:dd:dc:eb:6d:a1" >functions/ecm.usb0/dev_addr
ln -sf functions/ecm.usb0 configs/c.1/

udevadm settle -t 5 || :

echo "${udc}" >UDC

sleep 2
systemctl restart systemd-networkd
