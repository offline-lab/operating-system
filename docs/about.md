# About

## Purpose

Offline Lab is an open-source platform for running apps on low-power devices without internet.

At Offline lab, we build convenience software for off-the-grid and no-internet situations
where connectivity to the internet is not always guaranteed.




Our software is tailored to a purpose build operating system that is optimized
for low power and resource restraints devices and SBC's.

During the development phase, we build for raspberry pi zero 2w and qemu only,
but we aim to change this soon once our ideas conceptualize.


## The operating system

Our operating system LabOS is a very minimal OS build using buildroot.

Our operating system only runs a discovery service, an upgrade service and some
systemd components.

Most of the functionality, will be provided as

Our operating system is build around [Systemd's portable service](https://systemd.io/PORTABLE_SERVICES/),


## The

## The package spec

For this project, we provide

## Our tools








We are the opposite of a data center. Where cloud infrastructure serves millions, we serve a family or a community. A few Raspberry Pis, a stack of SD cards, and a USB powerbank is all you need.

## Philosophy

**Offline-first, not offline-only.** When internet is available, the platform syncs data and pulls updates. When it isn't, everything keeps working. The system never waits for a network that isn't there.

**Low power above all.** Every design decision optimizes for battery life. If something costs CPU or memory without directly serving users, it gets cut. No background polling, no unnecessary logging, no idle services.

**Simple over clever.** SQLite over PostgreSQL. Bind mounts over complex storage layers. Systemd over custom init scripts. Boring technology, no premature abstraction.

**Portable services.** Each application ships as a squashfs image with everything it needs. No package managers, no dependency resolution. Drop the image on the device and start it.

**Community-oriented.** This platform is for people who need tools for daily life without reliable internet: travelers, off-grid communities, people in underserved areas. Communication, knowledge, entertainment, and personal data.

## What this is not

This is not a survivalist project. We are not building for bunkers. We build for a much larger group of people who, for ordinary reasons, don't have internet and still need their tools to work.

## Who builds this

Offline Lab is an open-source community project. Contributions are welcome. See the [contributing guide](contributing.md) to get started.
