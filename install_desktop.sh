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
f_linux_ssh_server() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue}  Installing SSH server${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo apt install openssh-server -y
}

f_linux_upgrade() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Running a full upgrade${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want run full upgrade? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt update
    sudo apt upgrade -y
    sudo apt dist-upgrade -y
    sudo apt-get full-upgrade -y
    sudo apt autoremove -y
  fi
}

f_linux_basic_packages() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing basic packages${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install basic packages? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    # Develop tools
    sudo apt install git neofetch vim neovim tmux python3 python3-pip tlp jq  -y
    # Linux extras
    sudo apt install util-linux-extra gcc make wget bat mosh eza -y
    # ZSH and zsh tools
    sudo apt install zsh zsh-syntax-highlighting zsh-autosuggestions -y
    # Network tools
    sudo apt install curl net-tools dnsutils traceroute nmap wireless-tools wireshark iperf3 speedtest-cli -y
    sudo apt install picocom -y
    # Monitoring tools
    sudo apt install ncdu btop glances bmon htop -y
    # File managers
    sudo apt install filezilla -y
    # Add current user to dialout group to use the serial interfaces with picocom.
    sudo usermod -a -G dialout "$USER"
  fi
}

f_linux_desktop_packages() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing desktop packages ( guake kitty remmina) ${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install desktop packages? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install guake kitty remmina -y
  fi
}

f_linux_terminal(){
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing terminal packages ( zsh oh-my-zsh powerline) ${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install terminal packages? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    pip3 install --user powerline-status --break-system-packages
    sudo apt install -y fonts-powerline
    # Install Patched Font
    if [ ! -d "$HOME/.fonts" ]; then
      mkdir ~/.fonts
      sudo cp -a fonts/. ~/.fonts/
      fc-cache -vf ~/.fonts/
    fi
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
  fi
}


f_linux_bluetoothManager() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing bluetooth manager${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo apt install blueman -y 
  sudo systemctl enable bluetooth.service
  sudo systemctl start bluetooth.service
}

f_linux_ntp_client(){
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing ntp sec client${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install ntpsec? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install ntpsec -y
    sudo systemctl enable ntpsec.service
    sudo systemctl restart ntpsec.service  
  fi
}

f_linux_SecPackages() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Security Packages${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install Security Packages? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install hcxtools tilix maltego burpsuite -y 
    sudo apt install hydra beef-xss nikto wavemon -y
  fi
}

f_linux_kismet() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Compiling kismet${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install kismet? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo "${blue}###############################################################################${reset}"
    echo "${blue} Setting repo for kismet ${reset}"
    echo "${blue}###############################################################################${reset}"
    wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | sudo tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/noble noble main' | sudo tee /etc/apt/sources.list.d/kismet.list >/dev/null
    sudo apt-get update
    echo "${blue}###############################################################################${reset}"
    echo "${blue} Installing dependencies for kismet${reset}"
    echo "${blue}###############################################################################${reset}"
    sudo apt install build-essential libwebsockets-dev pkg-config zlib1g-dev -y
    sudo apt install libnl-3-dev libnl-genl-3-dev libcap-dev libpcap-dev libnm-dev -y 
    sudo apt install libdw-dev libsqlite3-dev libprotobuf-dev libprotobuf-c-dev -y 
    sudo apt install protobuf-compiler protobuf-c-compiler -y 
    sudo apt install libusb-1.0-0-dev -y
    sudo apt install python3 python3-setuptools python3-protobuf python3-requests -y
    sudo apt install python3-numpy python3-serial python3-usb python3-dev python3-paho-mqtt -y 
    sudo apt install python3-websockets libubertooth-dev libbtbb-dev -y

    echo "${blue}###############################################################################${reset}"
    echo "${blue} Installing GQRX${reset}"
    echo "${blue}###############################################################################${reset}"
    sudo apt-get install software-properties-common
    sudo apt-get install python3-launchpadlib
    sudo apt-get install gqrx-sdr -y

    echo "${blue}###############################################################################${reset}"
    echo "${blue} Installing GQRX${reset}"
    echo "${blue}###############################################################################${reset}"
    sudo apt install kismet -y
  fi
}

f_linux_yubiauth() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing yubi authenticator${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo apt install yubioath-desktop -y
}

f_linux_netbird() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Netbird client${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install Netbird client? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt-get install ca-certificates curl gnupg -y
    curl -sSL https://pkgs.netbird.io/debian/public.key | sudo gpg --dearmor --output /usr/share/keyrings/netbird-archive-keyring.gpg
    echo 'deb [signed-by=/usr/share/keyrings/netbird-archive-keyring.gpg] https://pkgs.netbird.io/debian stable main' | sudo tee /etc/apt/sources.list.d/netbird.list
    sudo apt-get update
    sudo apt-get install netbird -y
    sudo apt-get install netbird-ui -y
  fi
}

f_linux_forticlient() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Forticlient${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install Forticlient? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    wget -O - https://repo.fortinet.com/repo/forticlient/7.4/ubuntu22/DEB-GPG-KEY | gpg --dearmor | sudo tee /usr/share/keyrings/repo.fortinet.com.gpg   
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/repo.fortinet.com.gpg] https://repo.fortinet.com/repo/forticlient/7.4/ubuntu22/ stable non-free" | sudo tee /etc/apt/sources.list.d/repo.fortinet.com.list
    sudo apt update   
    sudo apt install forticlient -y
  fi
}

f_linux_protonvpnclient() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing ProtonVPN Client${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install ProtonVPN Client? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    wget https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb
    sudo dpkg -i ./protonvpn-stable-release_1.0.8_all.deb && sudo apt update
    sudo apt install proton-vpn-gnome-desktop -y
    sudo apt install gnome-shell-extension-appindicator -y
    sudo rm -rf ./protonvpn-stable-release_1.0.8_all.deb
  fi
}

f_linux_claudecodecli() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Claude Code CLI${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install Claude Code CLI? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    curl -fsSL https://claude.ai/install.sh | bash
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
  fi
}

f_linux_virt_manager() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Virt Manager${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install Virt Manager? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt update
    sudo apt install qemu-kvm libvirt-daemon-system virt-manager
    sudo usermod -aG libvirt $USER
  fi
}

f_linux_gpstools() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing GPS tools${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo apt install gpsd gpsd-clients libgps-dev -y
}

f_linux_brave() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing brave${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo curl -fsS https://dl.brave.com/install.sh | sh
}

f_linux_mullvad() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Mullvad browser${reset}"
  echo "${blue}###############################################################################${reset}"
  sudo curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc https://repository.mullvad.net/deb/mullvad-keyring.asc
  echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$( dpkg --print-architecture )] https://repository.mullvad.net/deb/stable stable main" | sudo tee /etc/apt/sources.list.d/mullvad.list
  sudo apt update
  sudo apt install mullvad-browser
}

f_linux_alphaDriver(){
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing RTL8812AU/21AU and RTL8814AU Wireless drivers${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install Wireless Drivers Alpha? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt update
    sudo apt upgrade -y
    #sudo apt install linux-headers-generic build-essential git -y
    sudo apt install dkms -y
    rm -rf $HOME/rtw88
    cd $HOME
    git clone https://github.com/lwfinger/rtw88
    cd $HOME/rtw88
    make
    sudo make install
    sudo make install_fw
    sudo cp rtw88.conf /etc/modprobe.d/
    cd $SCRIPT_DIR
  fi
}

f_linux_wifitools(){
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Wireless Tools${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install Wireless tools? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt update
    sudo apt install bully hashcat hcxdumptool hcxtools macchanger -y 
    sudo apt install aircrack-ng -y
    sudo apt install wifite -y
  fi
}

f_linux_metasploit(){
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Metasploit suite${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install Metasploit suite? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt update
    curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > $HOME/msfinstall
    chmod +x $HOME/msfinstall
    sudo bash $HOME/msfinstall
    echo "${red}###############################################################################${reset}"
    echo "${red} Start Metasploit console > msfconsole ${reset}"
    echo "${red} Verify database connection > db_status ${reset}"
    echo "${red} Update Metasploit > msfupdate ${reset}"
    echo "${red}###############################################################################${reset}" 
  fi
}

f_linux_spotify() {
  echo "${blue}###############################################################################${reset}"
  echo "${blue} Installing Spotify${reset}"
  echo "${blue}###############################################################################${reset}"
  read -r -p "Want install spotify? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      # Spotify installation on Ubuntu
      curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
      echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
      sudo apt-get update 
      sudo apt-get install spotify-client -y
  fi
}

f_linux_install_app() {
  # General Linux installation server and desktop
  f_linux_upgrade
  f_linux_basic_packages
  f_linux_desktop_packages
  f_linux_ntp_client
  f_linux_netbird
  f_linux_forticlient
  f_linux_protonvpnclient
  f_linux_claudecodecli
  f_linux_virt_manager
  f_linux_terminal
  # Ask if install desktop packages
  #read -r -p "Want to continue with desktop packages install? [y/N]" -n 1
  #echo # (optional) move to a new line
  #if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    #f_linux_brave
    #f_linux_mullvad
    #f_linux_spotify
    #f_linux_yubiauth
    #f_linux_bluetoothManager
  #fi
  #read -r -p "Want to continue with infosec (Kali) packages install? [y/N]" -n 1
  #echo # (optional) move to a new line
  #if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    #f_linux_SecPackages
    #f_linux_gpstools
  #fi
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
esac


echo "${blue}###############################################################################${reset}"
echo "${blue} Configuration steps${reset}"
echo "${blue}###############################################################################${reset}"
read -r -p "Want to configure apps (vim, tmux, kitty, git)? [y/N]" -n 1
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

echo " "
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
