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
echo "${green} Installing lazyvim${reset}"
echo "${green}########################################################${reset}"

# Check for LazyVim's signature configuration file
LAZY_CONFIG="$HOME/.config/nvim/lua/config/lazy.lua"
if [ -f "$LAZY_CONFIG" ]; then
  echo "${red}LazyVim is installed in $HOME/.config/nvim${reset}"
  exit 1
fi

echo "${green}#==> Updating package lists...${reset}"
sudo apt update

echo "${green}#==> Installing core dependencies, build tools, and ...${reset}"
# gcc/g++ are required by Treesitter to compile parsers (e.g., for C++, Bash, Python)
# npm and python3-venv are required by Mason.nvim to download and build LSPs
sudo apt install -y \
  git \
  make \
  gcc \
  g++ \
  unzip \
  wget \
  curl \
  ripgrep \
  fd-find \
  python3-venv \
  python3-pip \
  npm \
  xclip \
  wl-clipboard

echo "${green}#==> Installing NeoVim${reset}"
sudo apt remove neovim neovim-runtime -y
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
sudo mv /opt/nvim-linux-x86_64 /opt/nvim
rm nvim-linux-x86_64.tar.gz
sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
#nvim --version

# Debian packages 'fd' as 'fdfind' to avoid naming conflicts.
# Telescope and other Neovim plugins expect the binary to be named 'fd'.
if ! command -v fd &>/dev/null; then
  echo "${green}#==> Creating symlink for fd-find...${reset}"
  mkdir -p ~/.local/bin
  ln -sf "$(which fdfind)" ~/.local/bin/fd
  echo "${green}Symlink created in ~/.local/bin/fd. Ensure ~/.local/bin is in your PATH.${reset}"
fi

echo "${green}#==> Installing the latest Lazygit...${reset}"
# Lazygit in apt is often heavily outdated or missing, fetch the latest binary
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
rm lazygit.tar.gz lazygit

echo "${green}#==> Backing up existing Neovim data (if any)...${reset}"
# Hide output if directories don't exist
mv ~/.config/nvim ~/.config/nvim.bak.old 2>/dev/null || true
mv ~/.local/share/nvim ~/.local/share/nvim.bak.old 2>/dev/null || true
mv ~/.local/state/nvim ~/.local/state/nvim.bak.old 2>/dev/null || true
mv ~/.cache/nvim ~/.cache/nvim.bak.old 2>/dev/null || true

echo "${green}#==> Cloning LazyVim starter template...${reset}"
git clone https://github.com/LazyVim/starter ~/.config/nvim
# Remove the .git folder so you can add it to your own dotfiles repository later
rm -rf ~/.config/nvim/.git

echo "${green}#==> Setup complete!${reset}"
echo "${green}#Launch Neovim by typing 'nvim'. LazyVim will automatically bootstrap and install its plugins.${reset}"

# ********************************************
# VERSION INSTALLED SUMMARY
# ********************************************

#APP_VERSION=$(claude --version 2>/dev/null)
#if [[ -n "$APP_VERSION" ]]; then
#    echo "APP is installed: $APP_VERSION"
#else
#    echo "APP is not installed"
#fi
