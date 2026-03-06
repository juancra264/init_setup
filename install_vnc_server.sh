#!/bin/bash

# #############################################################################
## Set Colors for echo messages
# #############################################################################
red=$(tput setaf 1)
green=$(tput setaf 2)
blue=$(tput setaf 4)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
reset=$(tput sgr0)

# #############################################################################
## Global Variables
# #############################################################################
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# #############################################################################
# ## Functions Declarations
# #############################################################################
f_linux_vncserver() {
  sudo apt update
  sudo apt install x11vnc -y
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Setting VNC Server Password for ${USER}${reset}"
  echo "${blue}###############################################################################${reset}"
  VNC_PASS_DIR="/home/$USER/.vnc"
  VNC_PASS_FILE="$VNC_PASS_DIR/passwd"

  if [ ! -f "$VNC_PASS_FILE" ]; then
      echo "Setting up VNC password..."
      mkdir -p "$VNC_PASS_DIR"
      # This will prompt you for a password
      x11vnc -storepasswd "$VNC_PASS_FILE"
      chown -R $USER:$USER "$VNC_PASS_DIR"
  fi
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Configuring VNC Server Password${reset}"
  echo "${blue}###############################################################################${reset}"
  # Define the target path
  SERVICE_FILE="/etc/systemd/system/vncserver.service"
  # Use 'tee' to write the file with sudo privileges
cat <<EOF | sudo tee $SERVICE_FILE > /dev/null
[Unit]
Description=vncserver service
After=multi-user.target network.target
exit
[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -auth /var/run/sddm/* -display :0 -forever -loop -noxdamage -repeat -rfbauth $VNC_PASS_FILE -rfbport 5900 -shared
ExecStop=/usr/bin/killall x11vnc
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target

EOF
  # Set correct permissions
  sudo chmod 644 $SERVICE_FILE
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Enabling and Starting the  VNC Server${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo systemctl daemon-reload
  sudo systemctl enable vncserver.service
  sudo systemctl restart vncserver.service
  echo "${blue}###############################################################################${reset}"
  echo "${blue} VNC Server installed${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo systemctl status vncserver.service --no-pager
}

f_linux_install_app() {
  echo "${red}###############################################################################${reset}"
  echo "${red} Installing VNC Server${reset}"
  echo "${red}###############################################################################${reset}"
  # Ask if install desktop packages
  read -r -p "Want to continue installing VNC server? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    f_linux_vncserver
  fi
}


# #############################################################################
# error codes
# 0 - exited without problems
# 1 - parameters not supported were used or some unexpected error occurred
# 2 - OS not supported by this script
# 3 - installed version of rclone is up to date
# 4 - supported unzip tools are not available
# #############################################################################

set -e

# #############################################################################
#detect the platform
# #############################################################################
OS="$(uname)"
case $OS in
  Linux)
    OS='linux'
    ;;
  FreeBSD)
    OS='freebsd'
    ;;
  NetBSD)
    OS='netbsd'
    ;;
  OpenBSD)
    OS='openbsd'
    ;;
  Darwin)
    OS='osx'
    ;;
  SunOS)
    OS='solaris'
    echo 'OS not supported'
    exit 2
    ;;
  *)
    echo 'OS not supported'
    exit 2
    ;;
esac

OS_type="$(uname -m)"
case "$OS_type" in
  x86_64|amd64)
    OS_type='amd64'
    ;;
  i?86|x86)
    OS_type='386'
    ;;
  aarch64|arm64)
    OS_type='arm64'
    ;;
  armv7*)
    OS_type='arm-v7'
    ;;
  armv6*)
    OS_type='arm-v6'
    ;;
  arm*)
    OS_type='arm'
    ;;
  *)
    echo 'OS type not supported'
    exit 2
    ;;
esac

# #############################################################################
# Commands based on platform 
# #############################################################################
case "$OS" in
  'linux')
    #For Linux Systems
    f_linux_install_app
    ;;
  'freebsd'|'openbsd'|'netbsd')
    #For bsd Systems
    echo " This is a bsd"
    ;;
  'osx')
    #For MacOS systems
    echo " This is a MacOS: "
    echo "Setting up your Mac..."
    ;;
  *)
    echo 'OS not supported'
    exit 2
esac

if [ -f /var/run/reboot-required ]; then
  echo "${red}###############################################################################${reset}"
  echo "${red} Please reboot the system${reset}"
  echo "${red}###############################################################################${reset}"
fi

exit 0
