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
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing VNC Server${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo apt update
  sudo apt install x11vnc -y
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Setting VNC Server Password${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo x11vnc -storepasswd /etc/vncserver.pass
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Configuring VNC Server Password${reset}"
  echo "${blue}###############################################################################${reset}"
sudo cat << 'EOF' > /lib/systemd/system/vncserver.service
[Unit]
Description=vncserver service
After=display-manager.service network.target syslog.target
exit
[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -forever -display :0 -auth guess -loop -noxdamage -repeat -rfbauth /etc/vncserver.pass -rfbport 5900 -shared -bg -xrandr
ExecStop=/usr/bin/killall x11vnc
Restart=on-failure

[Install]
WantedBy=multi-user.target

EOF
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Enabling and Starting the  VNC Server${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo systemctl daemon-reload
  sudo systemctl enable vncserver.service
  sudo systemctl start vncserver.service
  echo "${blue}###############################################################################${reset}"
  echo "${blue} VNC Server installed${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo systemctl status vncserver.service
}

f_linux_install_app() {
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
