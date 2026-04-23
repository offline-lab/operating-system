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
#      SPDX-License-Identifier: GPL-2.0-only                                   #
#                                                                              #
################################################################################

ARG BASE_IMAGE=debian
ARG BASE_TAG=trixie

FROM ghcr.io/go-debos/debos:main    AS debos
FROM ${BASE_IMAGE}:${BASE_TAG}-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV GOPATH=/usr/local/go
ENV TERM=xterm-256color
ENV INITRD=No

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG APT_PROXY
ARG RASPI_KERNEL_VERSION=rpi-6.17.y

# hadolint ignore=DL3008
RUN true \
 && if [[ -n "${APT_PROXY}" ]] ; then echo "Acquire::http::Proxy \"${APT_PROXY}\";" > /etc/apt/apt.conf.d/01proxy ; fi \
 && apt-get -y update \
 && apt-get -y install --no-install-recommends  \
        apt-transport-https=*          \
        arch-install-scripts=*         \
        arch-test=*                    \
        bc=*                           \
        binfmt-support=*               \
        bison=*                        \
        bmap-tools=*                   \
        btrfs-progs=*                  \
        busybox=*                      \
        bzip2=*                        \
        ca-certificates=*              \
        coreutils=*                    \
        crossbuild-essential-arm64=*   \
        curl=*                         \
        debian-ports-archive-keyring=* \
        debootstrap=*                  \
        device-tree-compiler=*         \
        devscripts=*                   \
        dosfstools=*                   \
        e2fsprogs=*                    \
        equivs=*                       \
        f2fs-tools=*                   \
        fatresize=*                    \
        fdisk=*                        \
        file=*                         \
        flex=*                         \
        g++=*                          \
        gcc=*                          \
        gettext-base=*                 \
        git=*                          \
        gpg=*                          \
        grep=*                         \
        gzip=*                         \
        initramfs-tools=*              \
        ipxe-qemu=*                    \
        jq=*                           \
        kmod=*                         \
        kpartx=*                       \
        less=*                         \
        libarchive-tools=*             \
        libc6-dev=*                    \
        libcap2-bin=*                  \
        libgmp3-dev=*                  \
        libguestfs-tools=*             \
        libmpc-dev=*                   \
        libncurses-dev=*               \
        libostree-dev=*                \
        libssl-dev=*                   \
        linux-image-arm64=*            \
        make=*                         \
        makepkg=*                      \
        mmdebstrap=*                   \
        moreutils=*                    \
        mtree-netbsd=*                 \
        ncdu=*                         \
        openssh-client=*               \
        pacman-package-manager=*       \
        parted=*                       \
        pigz=*                         \
        pkg-config=*                   \
        procps=*                       \
        psmisc=*                       \
        python3-git=*                  \
        python3-ply=*                  \
        qemu-user-binfmt=*             \
        qemu-utils=*                   \
        quilt=*                        \
        rsync=*                        \
        squashfs-tools=*               \
        systemd=*                      \
        systemd-container=*            \
        systemd-resolved=*             \
        u-boot-tools=*                 \
        udev=*                         \
        unzip=*                        \
        util-linux=*                   \
        vim=*                          \
        wget=*                         \
        whois=*                        \
        wpasupplicant=*                \
        xfsprogs=*                     \
        xxd=*                          \
        xz-utils=*                     \
        zerofree=*                     \
        zip=*                          \
        zstd=*                         \
 \
 && rm -rf /var/lib/apt/lists/* \
 && curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh  | sh -s -- -b /usr/local/bin \
 && curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

COPY --chmod=0755 --chown=0:0 --from=debos /usr/local/bin/debos /usr/local/bin/debos

WORKDIR /work
VOLUME ["/build", "/output"]
