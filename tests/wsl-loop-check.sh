#!/usr/bin/env bash
set -u
modprobe loop 2>&1 || true
printf 'loop-control: '; ls -l /dev/loop-control 2>&1 || true
printf 'loop0: '; ls -l /dev/loop0 2>&1 || true
printf 'free loop: '; losetup -f 2>&1 || true
printf 'attached loops:\n'; losetup -a 2>&1 || true
printf 'filesystems:\n'; grep -E 'btrfs|vfat|ext4' /proc/filesystems || true
mkdir -p /var/tmp/astra-test
truncate -s 256M /var/tmp/astra-test/loop-check.img
printf 'truncate status=%s\n' "$?"
losetup -f --show -P /var/tmp/astra-test/loop-check.img
printf 'losetup status=%s\n' "$?"
losetup -a 2>&1 || true
