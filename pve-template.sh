#!/usr/bin/env bash
# ==============================================================================
# Script: prepare-template.sh
# Description: Generalize and clean Debian VM for Proxmox VE template creation.
# Run as root or with sudo.
# ==============================================================================

set -euo pipefail

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "[-] This script must be run as root (or via sudo)." >&2
   exit 1
fi

echo "[+] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt update -y
apt dist-upgrade -y

echo "[+] Installing essential packages (qemu-guest-agent, cloud-init)..."
apt install -y qemu-guest-agent cloud-init cloud-utils cloud-initramfs-growpart
systemctl enable qemu-guest-agent

echo "[+] Cleaning apt cache and package lists..."
apt autoremove --purge -y
apt clean
apt autoclean
rm -rf /var/lib/apt/lists/*

echo "[+] Resetting machine-id and D-Bus ID..."
# Truncating to 0 bytes ensures systemd recreates a unique ID on first boot
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

echo "[+] Removing existing SSH host keys (regenerated on clone boot)..."
rm -f /etc/ssh/ssh_host_*

# Optional: ensure SSH host keys regenerate on boot if cloud-init is not used
if ! grep -q "ssh-keygen -A" /etc/rc.local 2>/dev/null; then
  cat << 'EOF' > /etc/systemd/system/regenerate-ssh-host-keys.service
[Unit]
Description=Regenerate SSH host keys if missing
ConditionPathExistsGlob=!/etc/ssh/ssh_host_*_key
Before=ssh.service

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable regenerate-ssh-host-keys.service
fi

echo "[+] Cleaning cloud-init state (if installed)..."
if command -v cloud-init &> /dev/null; then
    cloud-init clean --logs --seed || true
fi

echo "[+] Clearing persistent network device rules and DHCP leases..."
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f /var/lib/dhcp/* /var/lib/NetworkManager/* 2>/dev/null || true

echo "[+] Cleaning logs and temporary files..."
find /var/log -type f -exec truncate -s 0 {} +
rm -rf /tmp/* /var/tmp/*

echo "[+] Clearing shell history for all users..."
history -c
rm -f /root/.bash_history
find /home -name ".bash_history" -exec rm -f {} + 2>/dev/null || true

echo "[+] Syncing disk..."
sync

echo "[✓] Generalization complete. Shutting down system now..."
shutdown -h now

