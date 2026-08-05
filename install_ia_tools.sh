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
# Install Claude Code
# ********************************************
echo "${green}##################################################################${reset}"
echo "${green} Installing Claude Code ${reset}"
echo "${green}##################################################################${reset}"
curl -fsSL https://claude.ai/install.sh | bash

# ********************************************
# Install Antigravity CLI (agy)
# ********************************************
echo "${green}##################################################################${reset}"
echo "${green} Installing Antigrativity CLI ${reset}"
echo "${green}##################################################################${reset}"
curl -fsSL https://antigravity.google/cli/install.sh | bash   

# ********************************************
# Install Codex CLI
# ********************************************
echo "${green}##################################################################${reset}"
echo "${green} Installing CODEX CLI ${reset}"
echo "${green}##################################################################${reset}"
curl -fsSL https://chatgpt.com/codex/install.sh | sh

# ********************************************
# VERSION INSTALLED SUMMARY
# ********************************************

CLAUDE_VERSION=$(claude --version 2>/dev/null)
if [[ -n "$CLAUDE_VERSION" ]]; then
    echo "Claude is installed: $CLAUDE_VERSION"
else
    echo "Claude is not installed"
fi


AGY_VERSION=$(agy --version 2>/dev/null)
if [[ -n "$AGY_VERSION" ]]; then
    echo "Antigravity CLI is installed: $AGY_VERSION"
else
    echo "Antigravity CLI is not installed"
fi


CODEX_VERSION=$(codex --version 2>/dev/null)
if [[ -n "$CODEX_VERSION" ]]; then
    echo "Codex CLI is installed: $CODEX_VERSION"
else
    echo "Codex CLI is not installed"
fi


