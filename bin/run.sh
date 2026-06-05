#!/usr/bin/env bash

declare -a arguments=(
    -machine virt
    -cpu cortex-a53
    -m 512M
    -smp 4
    -bios artifacts/qemu-arm64/u-boot.bin
    -drive "file=artifacts/qemu-arm64/qemu.img,format=raw,if=virtio,id=hd0"
    -nographic
)

exec qemu-system-aarch64 "${arguments[@]}"
