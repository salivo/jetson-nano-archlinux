#!/bin/bash
set -e

GREEN='\033[0;32m'
NC='\033[0m' # No Color

URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
FILENAME="ArchLinuxARM-aarch64-latest.tar.gz"
CACHE_DIR="./.cache"
ROOTFS_DIR="./rootfs"
TARBALL_PATH="$CACHE_DIR/$FILENAME"

mkdir -p "$CACHE_DIR"

echo -e "${GREEN}[*] Downloading $FILENAME to $CACHE_DIR ...${NC}"
wget -c "$URL" -O "$TARBALL_PATH"

if [ -d "$ROOTFS_DIR" ]; then
    echo -e "${GREEN}[!] Skipping extraction, $ROOTFS_DIR already exists.${NC}"
else
    echo -e "${GREEN}[*] Extracting $TARBALL_PATH into $ROOTFS_DIR ...${NC}"
    mkdir -p "$ROOTFS_DIR"
    tar -xpf "$TARBALL_PATH" -C "$ROOTFS_DIR"
fi

echo -e "${GREEN}[✔] Done. Root filesystem is in: $ROOTFS_DIR${NC}"
