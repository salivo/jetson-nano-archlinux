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

# === Disable mkinitcpio hook ===
if [[ -f "$MKINITCPIO_HOOK" ]]; then
    echo_green "[*] Disabling mkinitcpio pacman hook ..."
    mv "$MKINITCPIO_HOOK" "$MKINITCPIO_HOOK.disabled"
fi

# === Set IgnorePkg ===
PACMAN_CONF="$ROOTFS/etc/pacman.conf"

echo_green "[*] Setting IgnorePkg=linux-aarch64 in pacman.conf ..."

# If line with IgnorePkg exists commented or uncommented, replace it; else append
if grep -q -E '^\s*#?\s*IgnorePkg\s*=' "$PACMAN_CONF"; then
    # Replace first matching IgnorePkg line (commented or not) with uncommented setting
    sed -i '0,/^\s*#\?\s*IgnorePkg\s*=.*/s//IgnorePkg = linux-aarch64/' "$PACMAN_CONF"
else
    # Append at the end
    echo "IgnorePkg = linux-aarch64" >> "$PACMAN_CONF"
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

# Fix ownership and permissions (needs sudo)
REAL_USER=${SUDO_USER:-$(whoami)}
chown $REAL_USER:$REAL_USER ./config.conf

echo_green "[✔] Rootfs patching complete."

