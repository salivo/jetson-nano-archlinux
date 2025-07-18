#!/bin/bash
set -e

GREEN='\033[0;32m'
NC='\033[0m' # No Color

CONFIG_FILE="config.conf"
ROOTFS_DIR="./rootfs"
QEMU_PATH="/usr/bin/qemu-aarch64-static"

echo_green() {
    echo -e "${GREEN}$1${NC}"
}

# Load config
echo_green "[*] Loading config from $CONFIG_FILE ..."
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Missing $CONFIG_FILE!" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    echo "No packages defined in $CONFIG_FILE!" >&2
    exit 1
fi


# Copy qemu binary if not already present
if [[ ! -f "$ROOTFS_DIR$QEMU_PATH" ]]; then
    echo_green "[*] Copying qemu-aarch64-static into rootfs ..."
    mkdir -p "$(dirname "$ROOTFS_DIR$QEMU_PATH")"
    cp "$QEMU_PATH" "$ROOTFS_DIR$QEMU_PATH"
fi

# Run package installation inside proot
echo_green "[*] Init pacman keys ..."
pacman-key --gpgdir="$ROOTFS_DIR"/etc/pacman.d/gnupg --config="$ROOTFS_DIR"/etc/pacman.conf --populate-from="$ROOTFS_DIR"/usr/share/pacman/keyrings --init
proot -R "$ROOTFS_DIR" -q "$QEMU_PATH" /bin/bash -c "pacman-key --populate archlinuxarm"

echo_green "[*] Packages to install: ${PACKAGES[*]}"
sudo pacman -Sy "${PACKAGES[@]}"  --sysroot rootfs
# Enable services
if [[ ${#Services[@]} -gt 0 ]]; then
    echo_green "[*] Enabling services: ${Services[*]}"
    for service in "${Services[@]}"; do
        proot -0 -r "$ROOTFS_DIR" -q "$QEMU_PATH" /usr/bin/systemctl enable "$service"
    done
fi


echo_green "[✔] Done."
