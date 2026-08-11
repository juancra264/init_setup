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
# Install ESP-IDF in Debian
# ********************************************
echo "${green}########################################################${reset}"
echo "${green} Installing ESP-IDF${reset}"
echo "${green}########################################################${reset}"
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://dl.espressif.com/dl/eim/eim.gpg -o /etc/apt/keyrings/eim.gpg
sudo chmod 0644 /etc/apt/keyrings/eim.gpg

sudo curl -fsSL https://dl.espressif.com/dl/eim/eim.sources -o /etc/apt/sources.list.d/espressif.sources

sudo apt update
sudo apt install eim -y
eim install

# ********************************************
# VERSION INSTALLED SUMMARY
# ********************************************

#APP_VERSION=$(claude --version 2>/dev/null)
#if [[ -n "$APP_VERSION" ]]; then
#    echo "APP is installed: $APP_VERSION"
#else
#    echo "APP is not installed"
#fi
