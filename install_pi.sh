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
echo "${green} Installing pi${reset}"
echo "${green}##################################################################${reset}"
curl -fsSL https://pi.dev/install.sh | sh

# ********************************************
# VERSION INSTALLED SUMMARY
# ********************************************

PI_VERSION=$(pi --version 2>/dev/null)
if [[ -n "$PI_VERSION" ]]; then
  echo "PI installed: $PI_VERSION"
else
  echo "PI is not installed"
fi
