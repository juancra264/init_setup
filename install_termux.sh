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
# Update 
# ********************************************
echo "${green}##################################################################${reset}"
echo "${green} updates and upgrades ${reset}"
echo "${green}##################################################################${reset}"
pkg update
pkg upgrade

# ********************************************
# install basic apps 
# ********************************************
echo "${green}########################################################${reset}"
echo "${green} installing basic apps ${reset}"
echo "${green}########################################################${reset}"
pkg install termux-api libusb clang iperf3 dnsutils 
pkg install git vim neovim tmux jq 
pkg install make wget bat mosh eza
# ZSH and zsh tools
pkg install zsh 
# Network tools
pkg install curl net-tools dnsutils traceroute nmap iperf3 speedtest-go picocom
# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  chsh -s zsh
fi
# Install zsh plugins
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then                                                                                       
    git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
fi
# Install powerlevel10k
#if [ ! -d "$HOME/powerlevel10k" ]; then
#  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/powerlevel10k
#fi
if [ ! -d "$HOME/nettools" ]; then
      git clone https://github.com/juancra264/nettools.git $HOME/nettools
    else
      # update nettools
      cd $HOME/nettools
      git pull
      cd $SCRIPT_DIR
fi
rm -rf $HOME/.zshrc
cp $HOME/init_setup/config/zshrc/zshrc $HOME/.zshrc

rm -rf $HOME/.vimrc
ln -s $HOME/init_setup/config/vim/vimrc $HOME/.vimrc

rm -rf $HOME/.tmux.conf
ln -s $HOME/init_setup/config/tmux/tmux.conf $HOME/.tmux.conf

rm -rf ~/.tmux/plugins/tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

rm -rf $HOME/.gitconfig
ln -s $HOME/init_setup/config/git/gitconfig $HOME/.gitconfig
git config --global user.name "juancra264"
git config --global user.email "juancra264@hotmail.com"
git config --global user.username "juancra264"

# Install starship
pkg install starship

# for starship
echo "${green}###############################################################################${reset}"
echo "${green} Configuring starship${reset}"
echo "${green}###############################################################################${reset}"
rm -rf $HOME/.config/starship.toml
ln -s $HOME/init_setup/config/starship/starship.toml $HOME/.config/starship.toml


