#!/bin/bash
set -e

GREEN='\033[0;32m'
NC='\033[0m' # No Color

URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
FILENAME="ArchLinuxARM-aarch64-latest.tar.gz"
ROOTFS_DIR="./rootfs"

echo -e "${GREEN}[*] Downloading $FILENAME ...${NC}"
wget -c "$URL" -O "$FILENAME"

echo -e "${GREEN}[*] Cleaning existing $ROOTFS_DIR ...${NC}"
rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"

echo -e "${GREEN}[*] Extracting $FILENAME into $ROOTFS_DIR ...${NC}"
tar -xpf "$FILENAME" -C "$ROOTFS_DIR"

echo -e "${GREEN}[✔] Done. Root filesystem is in: $ROOTFS_DIR${NC}"
