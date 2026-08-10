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
echo "${green}########################################################${reset}"
echo "${green} Installing ${reset}"
echo "${green}########################################################${reset}"


# ********************************************
# VERSION INSTALLED SUMMARY
# ********************************************

#APP_VERSION=$(claude --version 2>/dev/null)
#if [[ -n "$APP_VERSION" ]]; then
#    echo "APP is installed: $APP_VERSION"
#else
#    echo "APP is not installed"
#fi


