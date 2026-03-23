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
f_linux_upgrade() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Running a full upgrade${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo pacman -Syu
    paru -Syu --noconfirm
  fi
}

f_linux_basic_packages() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing basic packages${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    # Develop tools
    sudo pacman -S git vim neovim tmux python3 tlp jq --noconfirm
    # Linux extras
    sudo pacman -S gcc make wget bat mosh eza --noconfirm
    sudo pacman -S neofetch --noconfirm
    # ZSH and zsh tools
    sudo pacman -S zsh zsh-syntax-highlighting zsh-autosuggestions --noconfirm
    # Network tools
    sudo pacman -S curl net-tools dnsutils traceroute nmap iperf3 speedtest-cli --noconfirm
    sudo pacman -S picocom --noconfirm
    sudo pacman -S wireshark-qt --noconfirm
    # Monitoring tools
    sudo pacman -S ncdu btop glances bmon htop --noconfirm
    # File managers
    sudo pacman -S filezilla --noconfirm
    # Add current user to dialout group to use the serial interfaces with picocom.
    #sudo usermod -a -G dialout "$USER"
    # Installing ntpsec client
    #sudo apt install ntpsec -y
    #sudo systemctl enable ntpsec.service
    #sudo systemctl restart ntpsec.service  
  fi
}

f_linux_terminal(){
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Terminal packages ( zsh oh-my-zsh powerline) ${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    #pip3 install --user powerline-status --break-system-packages
    #sudo apt install -y fonts-powerline
    # Install Patched Font
    #if [ ! -d "$HOME/.fonts" ]; then
    #  mkdir ~/.fonts
    #  sudo cp -a fonts/. ~/.fonts/
    #  fc-cache -vf ~/.fonts/
    #fi
    # Install Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
      sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
    fi
    # Install zsh plugins
    echo "${blue}###############################################################################${reset}"
    echo "${blue} Installing zsh plugins zsh-syntax-highlighting ${reset}"
    echo "${blue}###############################################################################${reset}"
    if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
      git clone https://github.com/zsh-users/zsh-syntax-highlighting $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
    fi
    echo "${blue}###############################################################################${reset}"
    echo "${blue} Installing zsh plugins zsh-syntax-highlighting ${reset}"
    echo "${blue}###############################################################################${reset}"
    if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
      git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
    fi
    # Install powerlevel10k
    echo "${blue}###############################################################################${reset}"
    echo "${blue} Installing zsh plugins zsh-syntax-highlighting ${reset}"
    echo "${blue}###############################################################################${reset}"
    if [ ! -d "$HOME/powerlevel10k" ]; then
      git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/powerlevel10k
    fi
    # Install nettools
    echo "${blue}###############################################################################${reset}"
    echo "${blue} Installing zsh plugins zsh-syntax-highlighting ${reset}"
    echo "${blue}###############################################################################${reset}"
    if [ ! -d "$HOME/nettools" ]; then
      git clone https://github.com/juancra264/nettools.git $HOME/nettools
    else
      # update nettools
      cd $HOME/nettools
      git pull
      cd $SCRIPT_DIR
    fi
    # Switch the shell.
    chsh -s $(which zsh)
    # Copy zshrc config
    echo "${blue}###############################################################################${reset}"
    echo "${blue} Configuring zshrc${reset}"
    echo "${blue}###############################################################################${reset}"
    rm -rf $HOME/.zshrc
    cp $HOME/init_setup/config/zshrc/zshrc $HOME/.zshrc
  fi
}

f_linux_desktop_packages() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Apps${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo pacman -S guake kitty remmina --noconfirm
    sudo pacman -S freerdp libvncserver --noconfirm
    sudo pacman -S spotify-launcher --noconfirm
    paru -S teams-for-linux --noconfirm 
    paru -S snapd --noconfirm
    sudo systemctl enable --now snapd.socket
    snap install asana-snap
    snap install drawio   
    # Install yay (if not already installed)
    sudo pacman -S --needed base-devel git
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
    cd ..
    # Install VS Code
    yay -S visual-studio-code-bin   
  fi
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Brave${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      sudo curl -fsS https://dl.brave.com/install.sh | sh
  fi
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Virt Manager${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo pacman -S qemu-full virt-manager swtpm --noconfirm 	  
    sudo usermod -aG libvirt $USER
    systemctl enable --now libvirtd.socket
    sudo virsh net-autostart default
  fi
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing yubi authenticator${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo pacman -S libusb --noconfirm
    sudo pacman -S ccid pcsclite --noconfirm
    sudo systemctl enable --now pcscd.service
    paru -S yubico-authenticator-bin --noconfirm   
  fi
  #echo "${blue}###############################################################################${reset}"
  #echo "${blue} Installing GPS tools${reset}"
  #echo "${blue}###############################################################################${reset}"
  #read -r -p "Continue? [y/N]" -n 1
  #echo # (optional) move to a new line
  #if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  #  sudo apt install gpsd gpsd-clients libgps-dev -y
  #fi
  # GNOME Shell extension cli
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing tweaks packages ${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo pacman -S python-pipx --noconfirm
    pipx ensurepath 
    pipx install gnome-extensions-cli
    gext install clipboard-indicator@tudmotu.com
    gext enable clipboard-indicator@tudmotu.com
    gext install workspace-indicator@gnome-shell-extensions.gcampax.github.com
    gext enable workspace-indicator@gnome-shell-extensions.gcampax.github.com
    gext install user-theme@gnome-shell-extensions.gcampax.github.com
    gext enable user-theme@gnome-shell-extensions.gcampax.github.com
    gext install forge@jmmaranan.com
    gext enable forge@jmmaranan.com
    gext install Vitals@CoreCoding.com   
    gext enable Vitals@CoreCoding.com
    gnome-extensions list --enabled
  fi
  # Configuring shortcuts
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Configuring shortcuts ${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    # Define the path and key ID
    KEY_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
    # Add the new keybinding to the list
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
    "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
    # Set the shortcut details for Guake terminal
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH name "Show/Hide Guake"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH command "guake -t"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH binding "<Alt>w"
    # Changing close window shortcut to alt+q
    gsettings set org.gnome.desktop.wm.keybindings close "['<Alt>q']"
  fi
  # Configuring Tweeking desktop settings
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Tweaking desktop settings ${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    gsettings set org.gnome.desktop.background picture-uri ''
    gsettings set org.gnome.desktop.background primary-color '#000000'
    gsettings set org.gnome.desktop.background color-shading-type 'solid'   
  fi
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Power Management Tools (laptops)${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    # Installing powertop and tlp
    sudo pacman -S powertop tlp tlp-rdw --noconfirm
    sudo systemctl mask power-profiles-daemon.service
    sudo systemctl enable --now tlp.service
    sudo tlp-stat -s
    # Enable laptop mode
    echo 5 | sudo tee /proc/sys/vm/laptop_mode
    # Enable Auto CPU Frequency Scaling
    paru -S auto-cpufreq --noconfirm
    sudo systemctl enable --now auto-cpufreq.service
  fi

}

f_linux_server_packages() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue}  Installing SSH server${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install openssh-server -y
    sudo systemctl enable ssh.service
    sudo systemctl start ssh.service
  fi
}

f_linux_vpns() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Netbird client${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    curl -fsSL https://pkgs.netbird.io/install.sh | sh
  fi
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Forticlient${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    paru -S forticlient --noconfirm
    sudo systemctl enable --now forticlient.service
  fi
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing ProtonVPN Client${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    pacman -S proton-vpn-cli --noconfirm
  fi
}

f_linux_config_apps(){
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Copying Configuration Files (vim, tmux, kitty, git)${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    # for vim
    echo "${blue}###############################################################################${reset}"
    echo "${blue} Configuring VIM${reset}"
    echo "${blue}###############################################################################${reset}"
    rm -rf $HOME/.vimrc
    ln -s $HOME/init_setup/config/vim/vimrc $HOME/.vimrc

    # for tmux
    echo "${blue}###############################################################################${reset}"
    echo "${blue} Configuring TMUX${reset}"
    echo "${blue}###############################################################################${reset}"
    rm -rf $HOME/.tmux.conf
    ln -s $HOME/init_setup/config/tmux/tmux.conf $HOME/.tmux.conf

    # for kitty config
    echo "${blue}###############################################################################${reset}"
    echo "${blue} Configuring KITTY${reset}"
    echo "${blue}###############################################################################${reset}"
    rm -rf $HOME/.config/kitty/kitty.conf
    mkdir -p $HOME/.config/kitty
    ln -s $HOME/init_setup/config/kitty/kitty.conf $HOME/.config/kitty/kitty.conf

    echo "${blue}###############################################################################${reset}"
    echo "${blue} Installing TMUX pluggings${reset}"
    echo "${blue}###############################################################################${reset}"
    # Plugin Manager - https://github.com/tmux-plugins/tpm
    # If you didn't use my dotfiles install script you'll need to:
    rm -rf ~/.tmux/plugins/tpm
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

    # for git config
    echo "${blue}###############################################################################${reset}"
    echo "${blue} Configuring Git${reset}"
    echo "${blue}###############################################################################${reset}"
    rm -rf $HOME/.gitconfig
    ln -s $HOME/init_setup/config/git/gitconfig $HOME/.gitconfig
    git config --global user.name "juancra264"
    git config --global user.email "juancra264@hotmail.com"
    git config --global user.username "juancra264"
  fi
}

f_linux_install_app() {
  # General Linux installation server and desktop
  f_linux_upgrade
  f_linux_basic_packages
  f_linux_terminal
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Desktop Packages${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    f_linux_desktop_packages  
  fi
  #echo "${blue}###############################################################################${reset}"
  #echo "${blue} Installing Server Packages${reset}"
  #echo "${blue}###############################################################################${reset}"
  #read -r -p "Continue? [y/N]" -n 1
  #echo # (optional) move to a new line
  #if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  #  f_linux_server_packages  
  #fi
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing VPNs clients${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    f_linux_vpns
  fi
  f_linux_config_apps
  
  # adjust the timezone to chicago
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
  'osx')
    #For MacOS systems
    echo " This is a MacOS: "
    echo "Setting up your Mac..."

    # Removes .zshrc from $HOME (if it exists) and symlinks the .zshrc file from the .dotfiles
    #rm -rf $HOME/.zshrc
    #ln -s $HOME/dotfiles/zshrc/.zshrc $HOME/.zshrc

    # Update Homebrew recipes
    brew update

    # Install all our dependencies with bundle (See Brewfile)
    brew tap homebrew/bundle
    brew bundle --file $HOME/dotfiles/brew/Brewfile

    # for kitty config
    #rm -rf $HOME/.config/kitty/kitty.conf
    #mkdir -p $HOME/.config/kitty
    #ln -s $HOME/dotfiles/kitty/kitty.conf $HOME/.config/kitty/kitty.conf
    ;;
  *)
    echo 'OS not supported'
    exit 2
    ;;
esac

echo "${green}###############################################################################${reset}"
echo "${green} Installing and configuration complete !!!! ${reset}"
echo "${green}###############################################################################${reset}"

#echo " "
#echo "${cyan}###############################################################################${reset}"
#echo "${cyan} Install Oh-my-zsh and power level${reset}"
#echo "${cyan}###############################################################################${reset}"
#echo "${cyan} Manual Installation:${reset}"
#echo 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
#echo 'git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions'
#echo 'cp /etc/skel/.zshrc ~/.zshrc'
#echo 'git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k'
#echo "echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc"

if [ -f /var/run/reboot-required ]; then
  echo "${red}###############################################################################${reset}"
  echo "${red} Please reboot the system${reset}"
  echo "${red}###############################################################################${reset}"
  read -r -p "Want to reboot the system? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      sudo reboot
  fi
fi

exit 0
