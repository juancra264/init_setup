#!/bin/bash
#!/bin/bash

# Usage: sudo ./setup_user.sh <username>

# 1. Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)."
   exit 1
fi

# 2. Check if username is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USER_NAME=$1

# 3. Create the user
# -m: creates the home directory
# -s: sets the default shell to bash
if id "$USER_NAME" &>/dev/null; then
    echo "User $USER_NAME already exists. Skipping creation."
else
    useradd -m -s /bin/bash "$USER_NAME"
    echo "User $USER_NAME created."
    
    # Set a temporary password (optional - user should change this)
    echo "Please set a password for $USER_NAME:"
    passwd "$USER_NAME"
fi

# 4. Add to groups (sudo and docker)
# -aG: appends the user to the specified groups
usermod -aG sudo,docker "$USER_NAME"
echo "User $USER_NAME added to sudo and docker groups."
#
## 5. Prepare SSH directory
HOME_DIR="/home/$USER_NAME"
mkdir -p "$HOME_DIR/.ssh"
chmod 700 "$HOME_DIR/.ssh"
touch "$HOME_DIR/.ssh/authorized_keys"
chmod 600 "$HOME_DIR/.ssh/authorized_keys"
chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR/.ssh"
#
#echo "SSH directory initialized at $HOME_DIR/.ssh"
echo "Setup complete for $USER_NAME."
