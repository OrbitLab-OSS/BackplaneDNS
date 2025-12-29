#!/bin/bash

set -eou pipefail

if [ "${CHROOT:-'unset'}" == "unset" ]; then
    echo "CHROOT was not provided."
    exit 1
fi
version="${VERSION:-dev}"

# Make sure it's installed
sudo apt install -y debootstrap

set -o xtrace

# Create root filesystem build directory
mkdir "$CHROOT/bp-dns-fs"

# Install debian/trixie into build directory
sudo debootstrap --variant=minbase trixie "$CHROOT/bp-dns-fs" http://deb.debian.org/debian

# Add current resolv.conf for network resolution
sudo cp /etc/resolv.conf "$CHROOT/bp-dns-fs/etc/resolv.conf"

# Install repo files
sudo install -Dm755 "$CHROOT/scripts/coredns" "$CHROOT/bp-dns-fs/usr/bin/coredns"
sudo mkdir "$CHROOT/bp-dns-fs/etc/coredns" 
sudo cp "$CHROOT/resources/Corefile" "$CHROOT/bp-dns-fs/etc/coredns"
sudo cp "$CHROOT/resources/coredns.service" "$CHROOT/bp-dns-fs/usr/lib/systemd/system"

# Mount these for chroot
sudo mount --bind /proc "$CHROOT/bp-dns-fs/proc"
sudo mount --bind /sys  "$CHROOT/bp-dns-fs/sys"
sudo mount --bind /dev  "$CHROOT/bp-dns-fs/dev"

# Run commands to configure the root filesystem
sudo chroot "$CHROOT/bp-dns-fs" apt update -y
sudo chroot "$CHROOT/bp-dns-fs" apt install -y systemd-sysv ifupdown iproute2 netbase procps dnsutils ca-certificates iputils-ping
sudo chroot "$CHROOT/bp-dns-fs" systemctl enable coredns

# Unmount 
sudo umount "$CHROOT/bp-dns-fs/proc"
sudo umount "$CHROOT/bp-dns-fs/sys"
sudo umount "$CHROOT/bp-dns-fs/dev"

# Remove resolv.conf from root filesystem
sudo rm -f "$CHROOT/bp-dns-fs/etc/resolv.conf"

# Create tarball for usage as LXC appliance
sudo tar --numeric-owner -czf "backplane-dns-${version}.tar.gz" -C "$CHROOT/bp-dns-fs" .
sha256sum backplane-dns-${version}.tar.gz > backplane-dns-${version}.tar.gz.sha256
