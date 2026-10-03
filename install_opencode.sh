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
echo "${green} Installing opencode${reset}"
echo "${green}##################################################################${reset}"
curl -fsSL https://opencode.ai/install | bash
# ********************************************
# VERSION INSTALLED SUMMARY
# ********************************************

OPENCODE_VERSION=$(opencode --version 2>/dev/null)
if [[ -n "$OPENCODE_VERSION" ]]; then
  echo "OPENCODE installed: $OPENCODE_VERSION"
else
  echo "OPENCODE is not installed"
fi
