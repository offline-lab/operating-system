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

ARG BASE_IMAGE=debian
ARG BASE_TAG=trixie

FROM ${BASE_IMAGE}:${BASE_TAG}
SHELL ["/bin/bash", "-o", "pipefail", "-x", "-c"]
WORKDIR /work

ARG APT_PROXY

COPY --link --chown=0:0 ./.packages.list /etc/packages.list

ENV DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/root/.cache \
    --mount=type=cache,sharing=locked,target=/var/cache/apt \
    readarray -t packages < <( grep -vE '^#|^$' /etc/packages.list ) \
 && if [[ -n "${APT_PROXY}" ]] ; then echo "Acquire::http::Proxy \"${APT_PROXY}\";" > /etc/apt/apt.conf.d/01proxy ; fi \
 && apt-get update  --yes --allow-releaseinfo-change \
 && apt-get install --yes --no-install-recommends -y "${packages[@]}" \
 && rm -rf /var/lib/apt/lists/* \
 \
 && groupadd --gid 1000 builder \
 && useradd \
    --create-home \
    --home /builder \
    --shell /bin/bash \
    --uid 1000 \
    --gid 1000 \
    --groups builder \
    builder \
 && usermod -aG sudo builder \
 && echo 'builder ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
 \
 && mkdir -p /buildroot /builder /downloads /cache /artifacts \
 && chown -R builder:builder /buildroot /builder /downloads /cache /artifacts

USER builder
SHELL ["/bin/bash", "-o", "pipefail", "-x", "-c"]
WORKDIR /builder
STOPSIGNAL SIGINT

ENV BR2_DL_DIR=/downloads
ENV BR2_OUTPUT_DIR=/artifacts
ENV BR2_CACHE_DIR=/cache
ENV BR2_EXTERNAL=/work/br2-external

ENV HOME=/builder
ENV TERM=xterm-256color
ENV PATH="${HOME}/bin:${PATH}"

RUN git clone --depth 1 https://github.com/offline-lab/buildroot.git /buildroot
VOLUME ["/buildroot", "/work", "/downloads", "/cache", "/artifacts"]
