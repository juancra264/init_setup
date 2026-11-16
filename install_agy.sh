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
# Install Antigravity CLI (agy)
# ********************************************
echo "${green}##################################################################${reset}"
echo "${green} Installing Antigrativity CLI ${reset}"
echo "${green}##################################################################${reset}"
curl -fsSL https://antigravity.google/cli/install.sh | bash

# ********************************************
# VERSION INSTALLED SUMMARY
# ********************************************

AGY_VERSION=$(agy --version 2>/dev/null)
if [[ -n "$AGY_VERSION" ]]; then
  echo "Antigravity CLI is installed: $AGY_VERSION"
else
  echo "Antigravity CLI is not installed"
fi
