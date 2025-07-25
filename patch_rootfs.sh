#!/bin/bash
set -e

GREEN='\033[0;32m'
NC='\033[0m'

CONFIG_FILE="./config.conf"
ROOTFS="./rootfs"
SCRIPTS="./rootfs_scripts"
PACMAN_CONF="$ROOTFS/etc/pacman.conf"
RESOLV_CONF="$ROOTFS/etc/resolv.conf"
HOSTNAME_FILE="$ROOTFS/etc/hostname"
MKINITCPIO_HOOK="$ROOTFS/usr/share/libalpm/hooks/90-mkinitcpio-install.hook"

echo_green() {
    echo -e "${GREEN}$1${NC}"
}

# Load config
echo_green "[*] Loading configuration from $CONFIG_FILE ..."
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Missing $CONFIG_FILE!" >&2
    exit 1
fi

source "$CONFIG_FILE"

# === Hostname patching ===
base_hostname="${base_hostname,,}"  # lowercase
change_flag="${change,,}"           # lowercase
start_count="${start_count:-1}"

if [[ "$change_flag" =~ ^(true|yes|1)$ ]]; then
    current_count="$start_count"
    [[ -f "$HOSTNAME_FILE" ]] && {
        prev="$(cat "$HOSTNAME_FILE")"
        if [[ "$prev" =~ ^${base_hostname}_[0-9]+$ ]]; then
            prev_count="${prev##*_}"
            current_count=$((prev_count + 1))
        fi
    }
    new_hostname="${base_hostname}_${current_count}"
    echo "$new_hostname" > "$HOSTNAME_FILE"
    echo_green "[*] Updated hostname to: $new_hostname"

    # Update start_count in config.conf
    tmpfile="$(mktemp)"
    awk -v count="$((current_count + 1))" '
      BEGIN { updated = 0 }
      /^start_count=/ {
        print "start_count=" count
        updated = 1
        next
      }
      { print }
      END {
        if (!updated) print "start_count=" count
      }
    ' "$CONFIG_FILE" > "$tmpfile"
    mv "$tmpfile" "$CONFIG_FILE"
    echo_green "[*] Updated start_count=$((current_count + 1)) in config.conf"
else
    echo "$base_hostname" > "$HOSTNAME_FILE"
    echo_green "[*] Set hostname to: $base_hostname"
fi

# === Patch mkinitcpio ===

echo_green "[*] Patching mkinitcpio ..."

# Patch mkinitcpio.conf with desired HOOKS
MKINITCPIO_CONF="$ROOTFS/etc/mkinitcpio.conf"
echo_green "[*] Updating mkinitcpio.conf HOOKS ..."

if [[ -f "$MKINITCPIO_CONF" ]]; then
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block filesystems fsck)/' "$MKINITCPIO_CONF"
else
    echo "[!] mkinitcpio.conf not found!" >&2
    exit 1
fi

# === Copy custom service files ===
echo_green "[*] Copying NVIDIA Tegra service/init files ..."
install -Dm644 "$SCRIPTS/nvidia-tegra.service" "$ROOTFS/usr/lib/systemd/system/nvidia-tegra.service"
install -Dm755 "$SCRIPTS/nvidia-tegra-init-script" "$ROOTFS/usr/bin/nvidia-tegra-init-script"

# === Set resolv.conf ===
echo_green "[*] Writing resolv.conf with Cloudflare & Google DNS ..."
rm "$RESOLV_CONF"
touch "$RESOLV_CONF"
echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" > "$RESOLV_CONF"


# === Add custom Jetson-Nano repository ===
echo_green "[*] Adding Jetson-Nano repository to pacman.conf ..."
REPO_NAME="[jetson-nano]"
REPO_BLOCK=$(cat <<EOF
$REPO_NAME
Server = https://salivo.github.io/jetson-nano-archlinux-packages/aarch64/
EOF
)

FILE="$ROOTFS/etc/pacman.conf"

grep -Fxq "$REPO_NAME" "$FILE" || echo -e "\n$REPO_BLOCK" | sudo tee -a "$FILE"

# Fix config ownership and permissions 
REAL_USER=${SUDO_USER:-$(whoami)}
chown $REAL_USER:$REAL_USER ./config.conf

echo_green "[✔] Rootfs patching complete."

