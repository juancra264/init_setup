#!/bin/bash

## How to Use It
## chmod +x secure_server.sh
## sudo bash secure_server.sh {{your_username}}

# Exit on error
set -e

# Define variables
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_CONFIG="/etc/ssh/sshd_config.bak"
USER="$1"
AUTHORIZED_KEYS="/home/$USER/.ssh/authorized_keys"

# Check if user is provided
if [ -z "$USER" ]; then
  echo "Usage: $0 <username>"
  exit 1
fi

if [ ! -f "$AUTHORIZED_KEYS" ]; then
  echo "authorized_keys file does not exist for user $USER."
  exit 2
fi

if [ ! -s "$AUTHORIZED_KEYS" ]; then
  echo "authorized_keys file exists but is empty for user $USER."
  exit 3
fi

# Backup sshd_config
if [ ! -f "$BACKUP_CONFIG" ]; then
  echo "Backing up sshd_config to $BACKUP_CONFIG"
  sudo cp "$SSHD_CONFIG" "$BACKUP_CONFIG"
fi

# Update sshd_config
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sudo sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
sudo sed -i 's/^#*UsePAM.*/UsePAM no/' "$SSHD_CONFIG"
sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
sudo sed -i 's|^#*AuthorizedKeysFile.*|AuthorizedKeysFile .ssh/authorized_keys|' "$SSHD_CONFIG"
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"

# Restart SSH service
sudo systemctl restart ssh

echo "SSH server configured to allow only key-based authentication for user $USER."

