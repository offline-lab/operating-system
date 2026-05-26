#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# Buildbox: non-interactive pipeline for building and testing Offline Lab OS
# images on a UTM virtual machine.
#
# Manages the full lifecycle: VM creation, provisioning, code sync, build,
# verification, and artifact retrieval.
#
# Usage:
#   bin/buildbox.sh                    # full pipeline: sync + build + verify
#   bin/buildbox.sh create             # create and provision a new buildbox VM
#   bin/buildbox.sh sync               # sync code to buildbox
#   bin/buildbox.sh build              # sync + build
#   bin/buildbox.sh verify             # run verification on remote artifacts
#   bin/buildbox.sh fetch              # download artifacts from buildbox
#   bin/buildbox.sh ssh [cmd]          # SSH into buildbox
#   bin/buildbox.sh destroy            # delete the buildbox VM
#
set -e -u -o pipefail

################################################################################
# Configuration
################################################################################

BASEDIR="$(cd "$(dirname "${0}")/.." && pwd)"
VM_NAME="${BUILDBOX_VM_NAME:-Buildbox}"
CACHE_DIR="${HOME}/.cache/buildroot/vm"
UTM_DIR="${HOME}/Library/Containers/com.utmapp.UTM/Data/Documents"
SSH_KEY="${BASEDIR}/.ssh/builder"
DEBIAN_URL="https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-arm64-daily.qcow2"

VM_CPUS=8
VM_MEMORY=24576
VM_DISK="60G"

REMOTE_USER="builder"
REMOTE_WORK="/home/builder/work"
REMOTE_BUILDROOT="/home/builder/buildroot"
REMOTE_ARTIFACTS="/home/builder/artifacts"

SSH_OPTS=(-F /dev/null -i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes)
REMOTE_HOST=""

################################################################################
# Logging
################################################################################

function log()     { printf '\e[1;32m>>>\e[0m %s\n' "${*}"; }
function log_err() { printf '\e[1;31m!!!\e[0m %s\n' "${*}" >&2; }
function log_dim() { printf '\e[0;90m    %s\e[0m\n' "${*}"; }

################################################################################
# SSH helpers
################################################################################

function bb_ssh() {
    SSH_AUTH_SOCK=/dev/null ssh "${SSH_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "${@}"
}

function bb_rsync() {
    SSH_AUTH_SOCK=/dev/null rsync -a --delete \
        -e "ssh ${SSH_OPTS[*]}" \
        "${@}"
}

function bb_scp() {
    SSH_AUTH_SOCK=/dev/null scp "${SSH_OPTS[@]}" "${@}"
}

################################################################################
# Resolve VM IP address
################################################################################

function resolve_host() {
    if [[ -n "${BUILDBOX_HOST:-}" ]]; then
        REMOTE_HOST="${BUILDBOX_HOST}"
        return 0
    fi

    local hosts_ip
    hosts_ip="$(awk '/^[^#].*buildbox/{print $1; exit}' /etc/hosts 2>/dev/null || true)"
    if [[ -n "${hosts_ip}" ]]; then
        REMOTE_HOST="${hosts_ip}"
        return 0
    fi

    if command -v utmctl &>/dev/null; then
        local status
        status="$(utmctl status "${VM_NAME}" 2>/dev/null || true)"
        if [[ "${status}" == *"started"* ]]; then
            local ip
            ip="$(utmctl ip-address "${VM_NAME}" 2>/dev/null | head -1 || true)"
            if [[ -n "${ip}" ]]; then
                REMOTE_HOST="${ip}"
                return 0
            fi
        fi
    fi

    log_err "Cannot resolve buildbox address."
    log_err "Set BUILDBOX_HOST=<ip>, add 'buildbox' to /etc/hosts, or create a VM with: ${0} create"
    return 1
}

################################################################################
# Wait for SSH to become available
################################################################################

function wait_for_ssh() {
    local host="${1}"
    local max_attempts="${2:-60}"
    local attempt=0

    log "Waiting for SSH on ${host}..."
    while [[ ${attempt} -lt ${max_attempts} ]]; do
        if SSH_AUTH_SOCK=/dev/null ssh "${SSH_OPTS[@]}" -o ConnectTimeout=3 \
            "${REMOTE_USER}@${host}" true 2>/dev/null; then
            log "SSH available"
            return 0
        fi
        ((attempt++))
        sleep 5
    done

    log_err "SSH not available after $((max_attempts * 5))s"
    return 1
}

################################################################################
# Wait for cloud-init to finish
################################################################################

function wait_for_cloudinit() {
    log "Waiting for cloud-init to complete provisioning..."
    local max_attempts=60
    local attempt=0

    while [[ ${attempt} -lt ${max_attempts} ]]; do
        if bb_ssh 'test -f /var/lib/cloud/instance/boot-finished' 2>/dev/null; then
            log "Cloud-init finished"
            return 0
        fi
        ((attempt++))
        sleep 10
    done

    log_err "Cloud-init did not finish within $((max_attempts * 10))s"
    return 1
}

################################################################################
# Create cloud-init ISO
################################################################################

function create_cidata_iso() {
    local iso="${CACHE_DIR}/cidata.iso"
    local tmpdir
    tmpdir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${tmpdir}'" RETURN

    cp "${BASEDIR}/bin/buildbox/cloud-init/user-data" "${tmpdir}/user-data"
    cp "${BASEDIR}/bin/buildbox/cloud-init/meta-data" "${tmpdir}/meta-data"

    hdiutil makehybrid -o "${iso}" "${tmpdir}" \
        -iso -joliet -default-volume-name cidata 2>/dev/null

    if [[ -f "${iso}.iso" ]] && [[ ! -f "${iso}" ]]; then
        mv "${iso}.iso" "${iso}"
    fi

    echo "${iso}"
}

################################################################################
# Create UTM VM
################################################################################

function cmd_create() {
    for cmd in qemu-img curl hdiutil utmctl; do
        if ! command -v "${cmd}" &>/dev/null; then
            log_err "Required: ${cmd}"
            exit 1
        fi
    done

    local vm_dir="${UTM_DIR}/${VM_NAME}.utm"
    if [[ -d "${vm_dir}" ]]; then
        log_err "VM '${VM_NAME}' already exists. Run '${0} destroy' first."
        exit 1
    fi

    mkdir -p "${CACHE_DIR}"

    # Download Debian cloud image
    local img="${CACHE_DIR}/debian-13-generic-arm64.qcow2"
    if [[ ! -f "${img}" ]]; then
        log "Downloading Debian 13 arm64 cloud image..."
        curl -L -o "${img}" "${DEBIAN_URL}"
    else
        log "Using cached Debian cloud image"
    fi

    # Create cloud-init ISO
    log "Creating cloud-init ISO..."
    local iso
    iso="$(create_cidata_iso)"

    # Assemble UTM bundle
    log "Creating UTM VM: ${VM_NAME}"
    mkdir -p "${vm_dir}/Data"

    local disk_uuid cidata_uuid vm_uuid
    disk_uuid="$(uuidgen)"
    cidata_uuid="$(uuidgen)"
    vm_uuid="$(uuidgen)"

    cp "${img}" "${vm_dir}/Data/${disk_uuid}.qcow2"
    qemu-img resize "${vm_dir}/Data/${disk_uuid}.qcow2" "${VM_DISK}"
    cp "${iso}" "${vm_dir}/Data/${cidata_uuid}.iso"

    cat > "${vm_dir}/config.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Backend</key>
	<string>QEMU</string>
	<key>ConfigurationVersion</key>
	<integer>4</integer>
	<key>Display</key>
	<array>
		<dict>
			<key>DownscalingFilter</key>
			<string>Linear</string>
			<key>DynamicResolution</key>
			<true/>
			<key>Hardware</key>
			<string>virtio-gpu-gl-pci</string>
			<key>NativeResolution</key>
			<false/>
			<key>UpscalingFilter</key>
			<string>Nearest</string>
		</dict>
	</array>
	<key>Drive</key>
	<array>
		<dict>
			<key>Identifier</key>
			<string>${cidata_uuid}</string>
			<key>ImageName</key>
			<string>${cidata_uuid}.iso</string>
			<key>ImageType</key>
			<string>CD</string>
			<key>Interface</key>
			<string>USB</string>
			<key>InterfaceVersion</key>
			<integer>1</integer>
			<key>ReadOnly</key>
			<true/>
		</dict>
		<dict>
			<key>Identifier</key>
			<string>${disk_uuid}</string>
			<key>ImageName</key>
			<string>${disk_uuid}.qcow2</string>
			<key>ImageType</key>
			<string>Disk</string>
			<key>Interface</key>
			<string>VirtIO</string>
			<key>InterfaceVersion</key>
			<integer>1</integer>
			<key>ReadOnly</key>
			<false/>
		</dict>
	</array>
	<key>Information</key>
	<dict>
		<key>Icon</key>
		<string>linux</string>
		<key>IconCustom</key>
		<false/>
		<key>Name</key>
		<string>${VM_NAME}</string>
		<key>UUID</key>
		<string>${vm_uuid}</string>
	</dict>
	<key>Input</key>
	<dict>
		<key>MaximumUsbShare</key>
		<integer>3</integer>
		<key>UsbBusSupport</key>
		<string>3.0</string>
		<key>UsbSharing</key>
		<false/>
	</dict>
	<key>Network</key>
	<array>
		<dict>
			<key>BridgeInterface</key>
			<string>en0</string>
			<key>Hardware</key>
			<string>virtio-net-pci</string>
			<key>IsolateFromHost</key>
			<false/>
			<key>Mode</key>
			<string>Bridged</string>
			<key>PortForward</key>
			<array/>
		</dict>
	</array>
	<key>QEMU</key>
	<dict>
		<key>AdditionalArguments</key>
		<array/>
		<key>BalloonDevice</key>
		<false/>
		<key>DebugLog</key>
		<false/>
		<key>Hypervisor</key>
		<true/>
		<key>PS2Controller</key>
		<false/>
		<key>RNGDevice</key>
		<true/>
		<key>RTCLocalTime</key>
		<false/>
		<key>TPMDevice</key>
		<false/>
		<key>TSO</key>
		<false/>
		<key>UEFIBoot</key>
		<true/>
	</dict>
	<key>Serial</key>
	<array/>
	<key>Sharing</key>
	<dict>
		<key>ClipboardSharing</key>
		<true/>
		<key>DirectoryShareMode</key>
		<string>VirtFS</string>
		<key>DirectoryShareReadOnly</key>
		<false/>
	</dict>
	<key>Sound</key>
	<array/>
	<key>System</key>
	<dict>
		<key>Architecture</key>
		<string>aarch64</string>
		<key>CPU</key>
		<string>default</string>
		<key>CPUCount</key>
		<integer>${VM_CPUS}</integer>
		<key>CPUFlagsAdd</key>
		<array/>
		<key>CPUFlagsRemove</key>
		<array/>
		<key>ForceMulticore</key>
		<false/>
		<key>JITCacheSize</key>
		<integer>0</integer>
		<key>MemorySize</key>
		<integer>${VM_MEMORY}</integer>
		<key>Target</key>
		<string>virt</string>
	</dict>
</dict>
</plist>
PLIST

    log "VM created. Starting..."
    utmctl start "${VM_NAME}" --hide

    # Wait for SSH
    sleep 10
    local ip=""
    local attempts=0
    while [[ -z "${ip}" ]] && [[ ${attempts} -lt 30 ]]; do
        ip="$(utmctl ip-address "${VM_NAME}" 2>/dev/null | head -1 || true)"
        ((attempts++))
        sleep 5
    done

    if [[ -z "${ip}" ]]; then
        log_err "Could not determine VM IP address"
        exit 1
    fi

    REMOTE_HOST="${ip}"
    log "VM IP: ${ip}"

    wait_for_ssh "${ip}" 60
    wait_for_cloudinit

    # Verify buildroot was cloned by cloud-init
    if ! bb_ssh 'test -d /home/builder/buildroot/Makefile' 2>/dev/null; then
        log "Buildroot not ready, cloning..."
        bb_ssh 'git clone --depth 1 https://github.com/offline-lab/buildroot.git /home/builder/buildroot'
    fi

    log "Buildbox ready at ${ip}"
    log "Add to /etc/hosts:  ${ip}  buildbox"
}

################################################################################
# Sync code to buildbox
################################################################################

function cmd_sync() {
    resolve_host

    log "Syncing code to ${REMOTE_HOST}..."

    bb_ssh "mkdir -p ${REMOTE_WORK}/bin ${REMOTE_WORK}/br2-external ${REMOTE_ARTIFACTS}"

    bb_rsync \
        --exclude '.git' \
        "${BASEDIR}/br2-external/" \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_WORK}/br2-external/"

    bb_rsync \
        "${BASEDIR}/bin/" \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_WORK}/bin/"

    if [[ -f "${BASEDIR}/.config" ]]; then
        bb_scp "${BASEDIR}/.config" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_WORK}/.config"
    fi

    log "Sync complete"
}

################################################################################
# Build on buildbox
################################################################################

function cmd_build() {
    resolve_host
    cmd_sync

    log "Starting build on ${REMOTE_HOST}..."
    local start_time
    start_time="$(date +%s)"

    if ! bb_ssh "bash ${REMOTE_WORK}/bin/build-native.sh" 2>&1 | while IFS= read -r line; do
        if [[ "${line}" == *">>>"* ]]; then
            log_dim "${line}"
        fi
    done; then
        local rc=${PIPESTATUS[0]}
        log_err "Build failed (exit code ${rc})"
        log_err "Full log: ssh builder@${REMOTE_HOST} cat /home/builder/build.log"
        return 1
    fi

    local end_time elapsed
    end_time="$(date +%s)"
    elapsed="$(( end_time - start_time ))"
    log "Build completed in $((elapsed / 60))m $((elapsed % 60))s"
}

################################################################################
# Verify on buildbox
################################################################################

function cmd_verify() {
    resolve_host

    log "Running verification on ${REMOTE_HOST}..."

    if ! bb_ssh "sudo bash ${REMOTE_WORK}/bin/verify.sh ${REMOTE_ARTIFACTS}/" 2>&1; then
        log_err "Verification failed"
        return 1
    fi

    log "Verification passed"
}

################################################################################
# Fetch artifacts from buildbox
################################################################################

function cmd_fetch() {
    resolve_host

    local local_artifacts="${BASEDIR}/artifacts"
    mkdir -p "${local_artifacts}"

    log "Fetching artifacts from ${REMOTE_HOST}..."

    bb_rsync \
        --include='offlinelab-sdcard-*.img.gz' \
        --include='rootfs.ext4' \
        --include='rootfs.ext2' \
        --include='Image' \
        --include='initramfs.cpio.gz' \
        --include='sdcard.img' \
        --include='*.dtb' \
        --exclude='*' \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_ARTIFACTS}/" \
        "${local_artifacts}/"

    log "Artifacts saved to ${local_artifacts}/"
    ls -lh "${local_artifacts}"/offlinelab-sdcard-*.img.gz 2>/dev/null || true
}

################################################################################
# SSH into buildbox
################################################################################

function cmd_ssh() {
    resolve_host
    SSH_AUTH_SOCK=/dev/null ssh "${SSH_OPTS[@]}" -t "${REMOTE_USER}@${REMOTE_HOST}" "${@}"
}

################################################################################
# Destroy buildbox VM
################################################################################

function cmd_destroy() {
    if ! command -v utmctl &>/dev/null; then
        log_err "utmctl not found"
        exit 1
    fi

    local status
    status="$(utmctl status "${VM_NAME}" 2>/dev/null || true)"

    if [[ "${status}" == *"started"* ]]; then
        log "Stopping ${VM_NAME}..."
        utmctl stop "${VM_NAME}" --kill
        sleep 3
    fi

    log "Deleting ${VM_NAME}..."
    utmctl delete "${VM_NAME}" 2>/dev/null || true
    log "VM deleted"
}

################################################################################
# Full pipeline: sync + build + verify
################################################################################

function cmd_pipeline() {
    local start_time
    start_time="$(date +%s)"

    log "=== Offline Lab OS build pipeline ==="

    cmd_build
    cmd_verify
    cmd_fetch

    local end_time elapsed
    end_time="$(date +%s)"
    elapsed="$(( end_time - start_time ))"

    log "=== Pipeline complete: $((elapsed / 60))m $((elapsed % 60))s ==="
}

################################################################################
# Usage
################################################################################

function cmd_usage() {
    cat <<EOF

  Buildbox — non-interactive build pipeline for Offline Lab OS

  Usage:
    bin/buildbox.sh                     Full pipeline: sync + build + verify + fetch
    bin/buildbox.sh create              Create and provision a new buildbox VM
    bin/buildbox.sh sync                Sync code to buildbox
    bin/buildbox.sh build               Sync + build
    bin/buildbox.sh verify              Run verification on remote artifacts
    bin/buildbox.sh fetch               Download artifacts from buildbox
    bin/buildbox.sh ssh [cmd]           SSH into buildbox
    bin/buildbox.sh destroy             Delete the buildbox VM

  Environment:
    BUILDBOX_HOST=<ip>                  Override buildbox address (default: from /etc/hosts or UTM)
    BUILDBOX_VM_NAME=<name>             Override VM name (default: Buildbox)

  Requires:
    - .ssh/builder key pair in the repo root
    - UTM + utmctl for VM management (or an existing host in /etc/hosts)

EOF
    exit 0
}

################################################################################
# Main
################################################################################

if [[ ! -f "${SSH_KEY}" ]]; then
    log_err "SSH key not found: ${SSH_KEY}"
    log_err "Create one: ssh-keygen -t ecdsa -f .ssh/builder -N ''"
    exit 1
fi

case "${1:-}" in
    create)   shift; cmd_create "${@}" ;;
    sync)     shift; cmd_sync "${@}" ;;
    build)    shift; cmd_build "${@}" ;;
    verify)   shift; cmd_verify "${@}" ;;
    fetch)    shift; cmd_fetch "${@}" ;;
    ssh)      shift; cmd_ssh "${@}" ;;
    destroy)  shift; cmd_destroy "${@}" ;;
    -h|--help|help) cmd_usage ;;
    "")       cmd_pipeline ;;
    *)        log_err "Unknown command: ${1}"; cmd_usage ;;
esac
