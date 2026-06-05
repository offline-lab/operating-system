#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2154,SC2155,SC2312
# SC2154: variables (TARGET_DIR, HOST_DIR, etc.) are exported by post-image.sh before sourcing this lib
# SC2312: find/cpio/date in subshells — return values are intentionally not checked here
# Sourced by boards/scripts/post-image.sh after the board hook.
# Requires: BUILD_DIR, TARGET_DIR, HOST_DIR, BINARIES_DIR,
#           BR2_EXTERNAL_OFFLINELAB_PATH, BOARD_DIR, COMMON_DIR, GENIMAGE_TMP
#           BOOT_CMD_FILE, BOARD_COMPATIBLE  (set by hook + meta)
#           gen_config()                     (defined by hook)

function build_initramfs() {
    local tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}"' RETURN

    mkdir -p "${tmpdir}"/{bin,sbin,etc,proc,sys,dev,mnt,newroot,data,tmp,overlay}

    cp "${TARGET_DIR}/bin/busybox" "${tmpdir}/bin/busybox"
    chmod 755 "${tmpdir}/bin/busybox"

    for cmd in sh mount umount mkdir switch_root cat echo sleep; do
        ln -s busybox "${tmpdir}/bin/${cmd}"
    done

    cp "${COMMON_DIR}/initramfs/init" "${tmpdir}/init"
    chmod 755 "${tmpdir}/init"

    (cd "${tmpdir}" && find . | cpio -o -H newc 2>/dev/null | gzip -9 \
        > "${BINARIES_DIR}/initramfs.cpio.gz")
}

function build_boot_scr() {
    "${HOST_DIR}/bin/mkimage" -C none -A arm64 -T script \
        -d "${BOOT_CMD_FILE}" "${BINARIES_DIR}/boot.scr"
}

function build_kernel_squashfs() {
    local tmpdir="$(mktemp -d)"
    cp "${BINARIES_DIR}/Image" "${tmpdir}/Image"
    "${HOST_DIR}/bin/mksquashfs" "${tmpdir}" "${BINARIES_DIR}/kernel-a.img" \
        -noappend -comp lzo -b 131072 -quiet
    rm -rf "${tmpdir}"
}

function create_overlay() {
    local tmpdir="$(mktemp -d)"
    mkdir -p "${tmpdir}/a/upper" "${tmpdir}/a/work"
    mkdir -p "${tmpdir}/b/upper" "${tmpdir}/b/work"
    mkfs.ext4 -F -d "${tmpdir}" -L "overlay" "${BINARIES_DIR}/overlay.ext4" 96M
    rm -rf "${tmpdir}"
}

function create_data() {
    local tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}"' RETURN

    mkdir -p "${tmpdir}/home/admin/.ssh"
    mkdir -p "${tmpdir}/apps" "${tmpdir}/extensions" "${tmpdir}/confexts" "${tmpdir}/config"

    if [[ -f "${BINARIES_DIR}/portable/hello-portable.raw" ]]; then
        cp "${BINARIES_DIR}/portable/hello-portable.raw" "${tmpdir}/apps/"
    fi

    chown -R 1000:1000 "${tmpdir}/home/admin"
    chmod 750 "${tmpdir}/home/admin"
    chmod 700 "${tmpdir}/home/admin/.ssh"

    mkfs.ext4 -F -d "${tmpdir}" -L "data" "${BINARIES_DIR}/data.ext4" 64M
}

function build_rauc_bundle() {
    local rauc_dir="${BR2_EXTERNAL_OFFLINELAB_PATH}/../.rauc"
    local bundle="${BINARIES_DIR}/offlinelab-update.raucb"
    local tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}"' RETURN

    rm -f "${bundle}"

    if [[ ! -f "${rauc_dir}/signing.key" ]]; then
        echo "WARNING: RAUC signing key not found at ${rauc_dir}/signing.key — skipping bundle"
        return 0
    fi

    cp "${BINARIES_DIR}/kernel-a.img" "${tmpdir}/kernel.img"
    cp "${BINARIES_DIR}/rootfs.ext4" "${tmpdir}/rootfs.img"

    cat > "${tmpdir}/manifest.raucm" <<EOF
[update]
compatible=${BOARD_COMPATIBLE}
version=$(date +%Y%m%d)

[bundle]
format=verity

[image.kernel]
filename=kernel.img

[image.rootfs]
filename=rootfs.img
EOF

    "${HOST_DIR}/bin/rauc" bundle \
        --cert="${rauc_dir}/signing.cert.pem" \
        --key="${rauc_dir}/signing.key" \
        "${tmpdir}" \
        "${bundle}"

    echo "RAUC bundle: ${bundle}"
}

function assemble() {
    local cfg="${BINARIES_DIR}/genimage.cfg"
    gen_config "${cfg}"

    trap 'rm -rf "${ROOTPATH_TMP}"' EXIT
    ROOTPATH_TMP="$(mktemp -d)"
    rm -rf "${GENIMAGE_TMP}"

    genimage \
        --rootpath "${ROOTPATH_TMP}" \
        --tmppath "${GENIMAGE_TMP}" \
        --inputpath "${BINARIES_DIR}" \
        --outputpath "${BINARIES_DIR}" \
        --config "${cfg}"
}
