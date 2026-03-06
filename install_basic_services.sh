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
f_linux_ssh_server() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} This is a linux${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo apt install openssh-server -y
}

f_linux_upgrade() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Upgrading${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo apt update
  sudo apt upgrade -y
  sudo apt dist-upgrade -y
  sudo apt-get full-upgrade -y
  sudo apt autoremove -y
}

f_linux_basic_packages() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing basic packages${reset}"
  echo "${blue}###############################################################################${reset}"
  # Develop tools
  sudo apt install git vim neovim tmux python3 python3-pip tlp jq  -y
  # Linux extras
  sudo apt install util-linux-extra gcc make wget bat mosh eza -y
  # ZSH and zsh tools
  sudo apt install zsh zsh-syntax-highlighting zsh-autosuggestions -y
  # Network tools
  sudo apt install net-tools dnsutils traceroute nmap wireless-tools wireshark iperf3 speedtest-cli -y
  sudo apt install picocom -y
  # Monitoring tools
  sudo apt install ncdu btop glances bmon htop -y
  # Add current user to dialout group to use the serial interfaces with picocom.
  sudo usermod -a -G dialout "$USER"
}

f_linux_install_ntp(){
  read -r -p "Want install ntpsec? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install ntpsec -y
    sudo systemctl enable ntpsec.service
    sudo systemctl restart ntpsec.service  
  fi
}

f_linux_install_app() {
  # General Linux installation server and desktop
  f_linux_ssh_server
  f_linux_upgrade
  f_linux_basic_packages
  f_linux_install_ntp
  sudo timedatectl set-timezone America/Chicago 
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
  *)
    echo 'OS not supported'
    exit 2
esac

echo " "
echo "${green}###############################################################################${reset}"
echo "${green} Installing Basic services complete !!!! ${reset}"
echo "${green}###############################################################################${reset}"

if [ -f /var/run/reboot-required ]; then
  echo "${red}###############################################################################${reset}"
  echo "${red} Please reboot the system${reset}"
  echo "${red}###############################################################################${reset}"
fi

exit 0
