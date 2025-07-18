#!/bin/bash
set -e

./create_archlinux_rootfs.sh
./patch_rootfs.sh
./install_all_rootfs.sh
