#!/usr/bin/env bash
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

# vi: ft=bash
# shellcheck shell=bash
#
# Buildbox: non-interactive pipeline for building and testing Offline Lab OS
# images on a lima VM (Apple Virtualization Framework).
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
VM_NAME="${BUILDBOX_VM_NAME:-buildbox}"
SSH_KEY="${BASEDIR}/.ssh/builder"

VM_CPUS=8
VM_MEMORY="24GiB"
VM_DISK="80GiB"

REMOTE_USER="builder"
REMOTE_WORK="/home/builder/work"
REMOTE_ARTIFACTS="/home/builder/artifacts"

SSH_OPTS=(-F /dev/null -i "${SSH_KEY}" -o IdentityAgent=none -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes)
REMOTE_HOST=""
SSH_PORT=""

################################################################################
# Shared library
################################################################################

# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"

################################################################################
# SSH helpers
################################################################################

# shellcheck disable=SC2029
function bb_ssh() {
    SSH_AUTH_SOCK=/dev/null ssh "${SSH_OPTS[@]}" -p "${SSH_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "${@}"
}

function bb_rsync() {
    local ssh_cmd
    ssh_cmd="ssh $(printf '%q ' "${SSH_OPTS[@]}") -p ${SSH_PORT}"
    SSH_AUTH_SOCK=/dev/null rsync -a --delete \
        -e "${ssh_cmd}" \
        "${@}"
}

function bb_scp() {
    SSH_AUTH_SOCK=/dev/null scp "${SSH_OPTS[@]}" -P "${SSH_PORT}" "${@}"
}

################################################################################
# Resolve VM SSH endpoint from lima
################################################################################

function resolve_host() {
    if [[ -n "${BUILDBOX_HOST:-}" ]]; then
        REMOTE_HOST="${BUILDBOX_HOST%%:*}"
        SSH_PORT="${BUILDBOX_HOST##*:}"
        [[ "${SSH_PORT}" == "${BUILDBOX_HOST}" ]] && SSH_PORT="22"
        return 0
    fi

    local port
    port="$(limactl list --json 2>/dev/null | jq -r "select(.name == \"${VM_NAME}\") | .sshLocalPort")"

    if [[ -z "${port}" ]] || [[ "${port}" == "null" ]] || [[ "${port}" == "0" ]]; then
        log_err "Lima VM '${VM_NAME}' not found or not running. Run: ${0} create"
        return 1
    fi

    REMOTE_HOST="127.0.0.1"
    SSH_PORT="${port}"
}

################################################################################
# Wait for SSH to become available
################################################################################

function wait_for_ssh() {
    local max_attempts="${1:-60}"
    local attempt=0

    log "Waiting for SSH on ${REMOTE_HOST}:${SSH_PORT}..."
    while [[ ${attempt} -lt ${max_attempts} ]]; do
        if SSH_AUTH_SOCK=/dev/null ssh "${SSH_OPTS[@]}" -p "${SSH_PORT}" -o ConnectTimeout=3 \
            "${REMOTE_USER}@${REMOTE_HOST}" true 2>/dev/null; then
            log "SSH available"
            return 0
        fi
        attempt=$((attempt + 1))
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
    local max_attempts=90
    local attempt=0

    while [[ ${attempt} -lt ${max_attempts} ]]; do
        if bb_ssh 'test -f /var/lib/cloud/instance/boot-finished' 2>/dev/null; then
            log "Cloud-init finished"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 10
    done

    log_err "Cloud-init did not finish within $((max_attempts * 10))s"
    return 1
}

################################################################################
# Create lima VM
################################################################################

function cmd_create() {
    if ! command -v limactl &>/dev/null; then
        log_err "limactl not found. Install: brew install lima"
        exit 1
    fi

    if limactl list --json 2>/dev/null | grep -q "\"name\":\"${VM_NAME}\""; then
        log_err "Lima VM '${VM_NAME}' already exists. Run '${0} destroy' first."
        exit 1
    fi

    if [[ ! -f "${SSH_KEY}.pub" ]]; then
        log_err "SSH public key not found: ${SSH_KEY}.pub"
        exit 1
    fi

    local pub_key
    pub_key="$(cat "${SSH_KEY}.pub")"

    local tmpconfig
    tmpconfig="$(mktemp /tmp/buildbox-lima-XXXX.yaml)"
    # shellcheck disable=SC2064
    trap "rm -f '${tmpconfig}'" RETURN

    cat >"${tmpconfig}" <<YAML
vmType: vz
arch: aarch64
rosetta:
  enabled: false

images:
  - location: "https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-arm64-daily.qcow2"
    arch: aarch64

cpus: ${VM_CPUS}
memory: "${VM_MEMORY}"
disk: "${VM_DISK}"

networks:
  - vzNAT: true

mounts: []

ssh:
  loadDotSSHPubKeys: false

provision:
  - mode: system
    script: |
      #!/bin/bash
      set -eux
      id builder &>/dev/null && exit 0
      useradd -m -s /bin/bash -c "Buildroot Builder" builder
      echo "builder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/builder
      chmod 440 /etc/sudoers.d/builder
      mkdir -p /home/builder/.ssh
      echo "${pub_key}" > /home/builder/.ssh/authorized_keys
      chown -R builder:builder /home/builder/.ssh
      chmod 700 /home/builder/.ssh
      chmod 600 /home/builder/.ssh/authorized_keys

  - mode: system
    script: |
      #!/bin/bash
      set -eux
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y --no-install-recommends \
        bc bison build-essential bzip2 ca-certificates ccache cmake \
        coreutils cpio curl device-tree-compiler dosfstools e2fsprogs \
        fakeroot fdisk file flex g++ gawk gcc genimage git grep gzip \
        jq kmod less librsvg2-bin libncurses-dev libssl-dev make \
        moreutils mtools ncdu parted pigz pkg-config procps rsync \
        squashfs-tools sudo u-boot-tools unzip util-linux vim wget \
        wpasupplicant xz-utils zip zstd

  - mode: user
    script: |
      #!/bin/bash
      # This runs as the lima default user, not builder — skip
      exit 0

  - mode: system
    script: |
      #!/bin/bash
      set -eux
      su - builder -c 'git clone --depth 1 https://github.com/offline-lab/buildroot.git /home/builder/buildroot'
      su - builder -c 'mkdir -p /home/builder/work /home/builder/downloads /home/builder/artifacts /home/builder/.ccache'
      su - builder -c 'ccache --max-size=15G'
YAML

    log "Creating lima VM: ${VM_NAME} (Apple Virt, ${VM_CPUS} CPUs, ${VM_MEMORY}, ${VM_DISK} disk)"
    limactl start --name="${VM_NAME}" --tty=false "${tmpconfig}"

    resolve_host
    log "VM SSH: ${REMOTE_HOST}:${SSH_PORT}"

    wait_for_ssh 60
    wait_for_cloudinit

    if ! bb_ssh 'test -f /home/builder/buildroot/Makefile' 2>/dev/null; then
        log "Cloning buildroot..."
        bb_ssh 'git clone --depth 1 https://github.com/offline-lab/buildroot.git /home/builder/buildroot'
    fi

    log "Buildbox ready."
    log "To connect: SSH_AUTH_SOCK=/dev/null ssh -i .ssh/builder -p ${SSH_PORT} builder@127.0.0.1"
}

################################################################################
# Sync code to buildbox
################################################################################

function cmd_sync() {
    resolve_host

    log "Syncing code to ${REMOTE_HOST}:${SSH_PORT}..."

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

    if [[ -f "${BASEDIR}/.ssh/builder.pub" ]]; then
        bb_ssh "mkdir -p ${REMOTE_WORK}/.ssh"
        bb_scp "${BASEDIR}/.ssh/builder.pub" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_WORK}/.ssh/builder.pub"
    fi

    if [[ -d "${BASEDIR}/.rauc" ]]; then
        bb_rsync \
            "${BASEDIR}/.rauc/" \
            "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_WORK}/.rauc/"
    fi

    if [[ -d "${BASEDIR}/framework" ]]; then
        bb_rsync \
            --exclude '.git' \
            "${BASEDIR}/framework/" \
            "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_WORK}/framework/"
    fi

    log "Sync complete"
}

################################################################################
# Build on buildbox
################################################################################

function cmd_build() {
    local board="${1:-pi-zero-2w}"
    local prod_flag=""
    [[ "${PRODUCTION}" -eq 1 ]] && prod_flag="--production"
    resolve_host
    cmd_sync

    log "Starting ${board} build on ${REMOTE_HOST}:${SSH_PORT}..."
    local start_time
    start_time="$(date +%s)"

    # shellcheck disable=SC2086
    if ! bb_ssh "bash ${REMOTE_WORK}/bin/build-image.sh ${prod_flag} ${board}" 2>&1 | while IFS= read -r line; do
        if [[ "${line}" == *">>>"* ]]; then
            log_dim "${line}"
        fi
    done; then
        log_err "${board} build failed"
        return 1
    fi

    local end_time elapsed
    end_time="$(date +%s)"
    elapsed="$((end_time - start_time))"
    log "Build completed in $((elapsed / 60))m $((elapsed % 60))s"
}

################################################################################
# Verify on buildbox
################################################################################

function cmd_verify() {
    local board="${1:-pi-zero-2w}"
    resolve_host

    log "Running verification on ${REMOTE_HOST}:${SSH_PORT}..."

    if ! bb_ssh "sudo bash ${REMOTE_WORK}/bin/verify.sh ${REMOTE_ARTIFACTS}/${board}/" 2>&1; then
        log_err "Verification failed"
        return 1
    fi

    log "Verification passed"
}

################################################################################
# Fetch artifacts from buildbox
################################################################################

function cmd_fetch() {
    local board="${1:-pi-zero-2w}"
    resolve_host

    local local_artifacts="${BASEDIR}/artifacts/${board}"
    mkdir -p "${local_artifacts}"

    log "Fetching ${board} artifacts from ${REMOTE_HOST}:${SSH_PORT}..."

    bb_rsync \
        --include='*.img.gz' \
        --include='*.img' \
        --include='*.bin' \
        --include='*.dtb' \
        --include='*.raucb' \
        --include='*.cdx.json' \
        --include='Image' \
        --include='initramfs.cpio.gz' \
        --include='boot.scr' \
        --include='kernel-a.img' \
        --exclude='*' \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_ARTIFACTS}/${board}/" \
        "${local_artifacts}/"

    log "Artifacts saved to ${local_artifacts}/"
    ls -lh "${local_artifacts}/"*.img.gz 2>/dev/null || true
}

################################################################################
# Tail build log on buildbox
################################################################################

function cmd_tail() {
    local board="${1:-pi-zero-2w}"
    cmd_ssh "tail -f ~/build-${board}.log"
}

################################################################################
# SSH into buildbox
################################################################################

function cmd_ssh() {
    resolve_host
    SSH_AUTH_SOCK=/dev/null ssh "${SSH_OPTS[@]}" -p "${SSH_PORT}" -t "${REMOTE_USER}@${REMOTE_HOST}" "${@}"
}

################################################################################
# Clean artifacts on buildbox
################################################################################

function cmd_clean_artifacts() {
    resolve_host

    log "Cleaning artifacts on ${REMOTE_HOST}:${SSH_PORT}..."
    bb_ssh "rm -rf ${REMOTE_ARTIFACTS:?}/* && echo 'done'"
    log "Artifacts cleaned"
}

################################################################################
# Destroy buildbox VM
################################################################################

function cmd_destroy() {
    if ! command -v limactl &>/dev/null; then
        log_err "limactl not found"
        exit 1
    fi

    if ! limactl list --json 2>/dev/null | grep -q "\"name\":\"${VM_NAME}\""; then
        log_err "Lima VM '${VM_NAME}' not found"
        exit 1
    fi

    log "Deleting lima VM: ${VM_NAME}..."
    limactl delete --force "${VM_NAME}"
    log "VM deleted"
}

################################################################################
# Full pipeline: sync + build + verify + fetch
################################################################################

function cmd_pipeline() {
    local board="${1:-pi-zero-2w}"
    local start_time
    start_time="$(date +%s)"

    log "=== Offline Lab OS build pipeline (${board}) ==="

    cmd_build "${board}"
    cmd_verify "${board}"
    cmd_fetch "${board}"

    local end_time elapsed
    end_time="$(date +%s)"
    elapsed="$((end_time - start_time))"

    log "=== Pipeline complete: $((elapsed / 60))m $((elapsed % 60))s ==="
}

function cmd_all() {
    local -a boards=()
    local defconfig board

    for defconfig in "${BASEDIR}/br2-external/configs/offlinelab_"*"_defconfig"; do
        board="$(basename "${defconfig}")"
        board="${board#offlinelab_}"
        board="${board%_defconfig}"
        board="${board//_/-}"
        [[ "${board}" == "common" ]] && continue
        boards+=("${board}")
    done

    local start_time total_start
    total_start="$(date +%s)"
    local failed=()

    log "=== Building all boards: ${boards[*]} ==="

    for board in "${boards[@]}"; do
        start_time="$(date +%s)"
        log "=== Starting ${board} ==="
        if cmd_build "${board}" && cmd_verify "${board}" && cmd_fetch "${board}"; then
            log "=== ${board} done in $(( ($(date +%s) - start_time) / 60 ))m ==="
        else
            log_err "=== ${board} FAILED ==="
            failed+=("${board}")
        fi
    done

    local elapsed=$(( $(date +%s) - total_start ))
    if [[ ${#failed[@]} -gt 0 ]]; then
        log_err "=== All boards done in $((elapsed / 60))m — FAILED: ${failed[*]} ==="
        return 1
    fi
    log "=== All boards done in $((elapsed / 60))m $((elapsed % 60))s ==="
}

################################################################################
# Usage
################################################################################

function cmd_usage() {
    cat <<EOF

  Buildbox — non-interactive build pipeline for Offline Lab OS

  Usage:
    bin/buildbox.sh [--production] [board]    Full pipeline (default: pi-zero-2w)
    bin/buildbox.sh all [--production]        Build all boards sequentially
    bin/buildbox.sh create                    Create and provision a new buildbox VM
    bin/buildbox.sh sync                      Sync code to buildbox
    bin/buildbox.sh build [--production] [board]   Sync + build
    bin/buildbox.sh verify [board]            Run verification on remote artifacts
    bin/buildbox.sh fetch [board]             Download artifacts from buildbox
    bin/buildbox.sh tail [board]              Tail the build log
    bin/buildbox.sh clean-artifacts           Remove all artifacts from buildbox
    bin/buildbox.sh ssh [cmd]                 SSH into buildbox
    bin/buildbox.sh destroy                   Delete the buildbox VM

  Flags:
    --production    Build without offlinelab-testing (no test users, no bootconf.yaml)
                    Default builds include testing for lab/CI use.

  Board examples:
    bin/buildbox.sh build pi-zero-2w
    bin/buildbox.sh --production build pi-zero-2w
    bin/buildbox.sh build qemu-arm64

  Environment:
    BUILDBOX_HOST=<ip>:<port>           Override buildbox SSH endpoint
    BUILDBOX_VM_NAME=<name>             Override VM name (default: buildbox)

  Requires:
    - .ssh/builder key pair in the repo root
    - limactl (brew install lima)

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

# Extract --production flag before command dispatch; applies to all build commands
PRODUCTION=0
_remaining_args=()
for _arg in "${@}"; do
    if [[ "${_arg}" == "--production" ]]; then
        PRODUCTION=1
    else
        _remaining_args+=("${_arg}")
    fi
done
set -- "${_remaining_args[@]}"

case "${1:-}" in
    all)            shift; cmd_all "${@}" ;;
    create)         shift; cmd_create "${@}" ;;
    sync)           shift; cmd_sync "${@}" ;;
    build)          shift; cmd_build "${@}" ;;
    verify)         shift; cmd_verify "${@}" ;;
    fetch)          shift; cmd_fetch "${@}" ;;
    tail)           shift; cmd_tail "${@}" ;;
    ssh)            shift; cmd_ssh "${@}" ;;
    clean-artifacts) shift; cmd_clean_artifacts "${@}" ;;
    destroy)        shift; cmd_destroy "${@}" ;;
    -h | --help | help) cmd_usage ;;
    "") cmd_pipeline ;;
    *)
        log_err "Unknown command: ${1}"
        cmd_usage
        ;;
esac
