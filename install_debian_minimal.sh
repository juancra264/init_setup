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

# ********************************************
# Install
# ********************************************
echo "${green}##################################################################${reset}"
echo "${green} Installing Debian minimal${reset}"
echo "${green}##################################################################${reset}"
sudo apt update
sudo apt full-upgrade -y

sudo apt install -y \
  sudo \
  curl \
  wget \
  vim \
  nano \
  htop \
  qemu-guest-agent \
  openssh-server \
  bash-completion \
  net-tools \
  dnsutils \
  ca-certificates \
  cloud-init

sudo systemctl enable --now qemu-guest-agent
sudo systemctl enable ssh
#sudo systemctl enable cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service

sudo apt clean
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s

history -c
rm -f ~/.bash_history
sudo rm -f /root/.bash_history

sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
