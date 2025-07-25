#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /dev/mmcblkX"
  exit 1
fi

DEV="$1"
ROOTFS_DIR="./rootfs"
MOUNT_POINT="/mnt/flash_rootfs"

# Check device exists and is block device
if [[ ! -b "$DEV" ]]; then
  echo "Error: Device $DEV not found or not a block device."
  exit 1
fi

echo "==> WARNING: This will erase all data on $DEV"
read -rp "Are you sure you want to continue? [yes/NO]: " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

# Unmount any mounted partitions on the device
echo "Unmounting partitions on $DEV..."
for part in $(lsblk -ln -o NAME "$DEV" | tail -n +2); do
  mountpoint=$(findmnt -nr -o TARGET "/dev/$part" || true)
  if [[ -n "$mountpoint" ]]; then
    echo "Unmounting /dev/$part from $mountpoint"
    umount "/dev/$part"
  fi
done

# Wipe partition table
echo "Creating new partition table on $DEV..."
parted "$DEV" --script mklabel msdos

# Create one primary partition (full device)
echo "Creating a new primary ext4 partition..."
parted "$DEV" --script mkpart primary ext4 1MiB 100%

# Give the kernel time to refresh partition table
sleep 2

# Get partition name, for example: /dev/mmcblk0p1 or /dev/sda1
if [[ "$DEV" == *"mmcblk"* || "$DEV" == *"nvme"* ]]; then
  PART="${DEV}p1"
else
  PART="${DEV}1"
fi

# Check if $PART already has ext4
echo "Checking if $PART is already ext4..."
fs_type=$(blkid -o value -s TYPE "$PART" || true)

if [[ "$fs_type" == "ext4" ]]; then
  echo "$PART already contains an ext4 filesystem, skipping format."
else
  echo "Formatting $PART as ext4..."
  mkfs.ext4 -F "$PART"
fi

# Mount partition
echo "Mounting $PART at $MOUNT_POINT ..."
mkdir -p "$MOUNT_POINT"
mount "$PART" "$MOUNT_POINT"

# Copy rootfs
echo "Cleaning all from $MOUNT_POINT/"
rm -rf "$MOUNT_POINT"/*

# Copy rootfs
echo "Copying rootfs from $ROOTFS_DIR to $MOUNT_POINT ..."
cp -a "$ROOTFS_DIR/." "$MOUNT_POINT/"

# Sync and unmount
echo "Syncing data to disk..."
sync

echo "Unmounting $PART ..."
umount "$MOUNT_POINT"

echo "Cleaning up..."
rmdir "$MOUNT_POINT"

echo "Done! $DEV is ready with rootfs."
