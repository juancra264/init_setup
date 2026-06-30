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
  echo "${green}###############################################################################${reset}"
  echo "${green} Running a full upgrade${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
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
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing basic packages (vim, zsh tools, filezilla, ntpsec, etc) ${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    # Develop tools
    sudo apt install sudo -y
    sudo apt install git vim neovim tmux python3 python3-pip tlp jq  -y
    # Linux extras
    sudo apt install util-linux-extra gcc make wget bat mosh eza -y
    # ZSH and zsh tools
    sudo apt install zsh zsh-syntax-highlighting zsh-autosuggestions -y
    # Network tools
    sudo apt install curl net-tools dnsutils traceroute nmap wireshark iperf3 speedtest-cli -y
    sudo apt install picocom -y
    # Monitoring tools
    sudo apt install ncdu btop glances bmon htop -y
    # File managers
    sudo apt install filezilla -y
    # Add current user to dialout group to use the serial interfaces with picocom.
    sudo usermod -a -G dialout "$USER"
    # Installing ntpsec client
    sudo apt install ntpsec -y
    sudo systemctl enable ntpsec.service
    sudo systemctl restart ntpsec.service  
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green}  Installing qemu-guest-agent${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    # Enable CPU optimizations:
    sudo apt install qemu-guest-agent -y
    sudo systemctl enable --now qemu-guest-agent
  fi
}

f_linux_terminal(){
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Terminal packages ( zsh oh-my-zsh powerline) ${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    pip3 install --user powerline-status --break-system-packages
    sudo apt install -y fonts-powerline
    sudo apt install -y kitty
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
    echo "${green}###############################################################################${reset}"
    echo "${green} Installing zsh plugins zsh-syntax-highlighting ${reset}"
    echo "${green}###############################################################################${reset}"
    if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
      git clone https://github.com/zsh-users/zsh-syntax-highlighting $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
    fi
    echo "${green}###############################################################################${reset}"
    echo "${green} Installing zsh plugins zsh-syntax-highlighting ${reset}"
    echo "${green}###############################################################################${reset}"
    if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
      git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
    fi
    # Install powerlevel10k
    echo "${green}###############################################################################${reset}"
    echo "${green} Installing zsh plugins zsh-syntax-highlighting ${reset}"
    echo "${green}###############################################################################${reset}"
    if [ ! -d "$HOME/powerlevel10k" ]; then
      git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/powerlevel10k
    fi
    # Install nettools
    echo "${green}###############################################################################${reset}"
    echo "${green} Installing zsh plugins zsh-syntax-highlighting ${reset}"
    echo "${green}###############################################################################${reset}"
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
    echo "${green}###############################################################################${reset}"
    echo "${green} Configuring zshrc${reset}"
    echo "${green}###############################################################################${reset}"
    rm -rf $HOME/.zshrc
    cp $HOME/init_setup/config/zshrc/zshrc $HOME/.zshrc
    sudo apt install kitty-terminfo
  fi
}

f_linux_desktop_packages() {
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Remmina ${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install remmina -y
    sudo apt install remmina-plugin-rdp remmina-plugin-secret remmina-plugin-vnc -y  
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing teams, Code, asana and drawio using snap${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install snapd -y 
    sudo snap refresh
    sudo snap install teams-for-linux   
    sudo snap install code --classic
    sudo snap install asana-snap
    sudo snap install drawio 
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Brave${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      sudo curl -fsS https://dl.brave.com/install.sh | sh
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Virt Manager${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install qemu-kvm libvirt-daemon-system virt-manager -y
    sudo usermod -aG libvirt $USER
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Spotify${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      # Spotify installation on Ubuntu
      curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
      echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
      sudo apt-get update 
      sudo apt-get install spotify-client -y
      sudo snap install spotify
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing yubi authenticator${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install yubioath-desktop -y
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing GPS tools${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install gpsd gpsd-clients libgps-dev -y
  fi
  # GNOME Shell extension cli
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing tweaks packages for GNOME ${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install -y gnome-tweaks gnome-shell-extension-manager   
    pip3 install --user gnome-extensions-cli --break-system-packages
    gext install clipboard-indicator@tudmotu.com
    gext enable clipboard-indicator@tudmotu.com
    gext install workspace-indicator@gnome-shell-extensions.gcampax.github.com
    gext enable workspace-indicator@gnome-shell-extensions.gcampax.github.com
    gext install ubuntu-appindicators@ubuntu.com
    gext enable ubuntu-appindicators@ubuntu.com
    gext install user-theme@gnome-shell-extensions.gcampax.github.com
    gext enable user-theme@gnome-shell-extensions.gcampax.github.com
    gext install forge@jmmaranan.com
    gext enable forge@jmmaranan.com
    gext install Vitals@CoreCoding.com   
    gext enable Vitals@CoreCoding.com
    gnome-extensions list --enabled
  fi
  # Remove the the Gnome dock
  echo "${green}###############################################################################${reset}"
  echo "${green} Remove Gnome dock ${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt remove gnome-shell-extension-ubuntu-dock -y
  fi
  # Configuring shortcuts
  echo "${green}###############################################################################${reset}"
  echo "${green} Configuring shortcuts for Gnome ${reset}"
  echo "${green}###############################################################################${reset}"
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
  echo "${green}###############################################################################${reset}"
  echo "${green} Tweaking desktop settings for GNOME ${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    gsettings set org.gnome.desktop.background picture-uri ''
    gsettings set org.gnome.desktop.background primary-color '#000000'
    gsettings set org.gnome.desktop.background color-shading-type 'solid'   
  fi
}

f_linux_server_packages() {
  echo "${green}###############################################################################${reset}"
  echo "${green}  Installing SSH service${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install openssh-server -y
    sudo systemctl enable ssh.service
    sudo systemctl start ssh.service
  fi
  # Fixing zhrc theme
  FILE="$HOME/.zshrc"
  SEARCH_STRING='ZSH_THEME="robbyrussell"'
  REPLACE_STRING='ZSH_THEME="agnoster"'
  if [ -f "$FILE" ]; then
    sed -i "s/$SEARCH_STRING/$REPLACE_STRING/g" "$FILE"
    echo "The theme has been replaced in $FILE."
  else
    echo "File $FILE does not exist."
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green}  Installing Docker ${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install ca-certificates curl gnupg -y
    sudo install -m 0755 -d /etc/apt/keyrings
    source /etc/os-release
    if [[ "$ID" == "debian" ]]; then
      curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null   
    elif [[ "$ID" == "ubuntu" ]]; then
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null   
    else
      echo "${red}###############################################################################${reset}"
      echo "${red}  THIS IS NO A DEBIAN OR UBUNTU SYSTEM ${reset}"
      echo "${red}###############################################################################${reset}"
    fi
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin  
    sudo systemctl enable --now docker
    # Check if dockergroup exists; create if missing
    GROUP_NAME="docker"
    if getent group "$GROUP_NAME" >/dev/null 2>&1; then
      echo "Group $GROUP_NAME already exists."
    else
      echo "Group $GROUP_NAME does not exist. Creating..."
      if sudo groupadd "$GROUP_NAME"; then
        echo "Successfully created group $GROUP_NAME."
      else
        echo "Error: Failed to create group $GROUP_NAME." >&2
        exit 1
      fi
    fi
    sudo usermod -aG docker ${USER}
    echo "${red}###############################################################################${reset}"
    echo "${red} Docker installed${reset}"
    echo "${red}###############################################################################${reset}"
    docker --version
    docker compose version
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green}  Optimize server for Containers${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    # Tune kernel for containers:
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    # Disable unnecessary services:
    source /etc/os-release
    if [[ "$ID" == "ubuntu" ]]; then
      sudo systemctl disable --now snapd.service
      sudo systemctl disable --now multipathd.service
      sudo systemctl disable --now apport.service
    fi
  fi

}

f_linux_Kali_Packages() {
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Kali Packages${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install hcxtools tilix maltego burpsuite -y 
    sudo apt install hydra beef-xss nikto wavemon -y
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Wireless Tools${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt update
    sudo apt install bully hashcat hcxdumptool hcxtools macchanger -y 
    sudo apt install aircrack-ng -y
    sudo apt install wifite -y
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing RTL8812AU/21AU and RTL8814AU Wireless drivers${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
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
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing bluetooth manager${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt install blueman -y 
    sudo systemctl enable bluetooth.service
    sudo systemctl start bluetooth.service
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Compiling kismet${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo "${green}###############################################################################${reset}"
    echo "${green} Setting repo for kismet ${reset}"
    echo "${green}###############################################################################${reset}"
    wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | sudo tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/noble noble main' | sudo tee /etc/apt/sources.list.d/kismet.list >/dev/null
    sudo apt-get update
    echo "${green}###############################################################################${reset}"
    echo "${green} Installing dependencies for kismet${reset}"
    echo "${green}###############################################################################${reset}"
    sudo apt install build-essential libwebsockets-dev pkg-config zlib1g-dev -y
    sudo apt install libnl-3-dev libnl-genl-3-dev libcap-dev libpcap-dev libnm-dev -y 
    sudo apt install libdw-dev libsqlite3-dev libprotobuf-dev libprotobuf-c-dev -y 
    sudo apt install protobuf-compiler protobuf-c-compiler -y 
    sudo apt install libusb-1.0-0-dev -y
    sudo apt install python3 python3-setuptools python3-protobuf python3-requests -y
    sudo apt install python3-numpy python3-serial python3-usb python3-dev python3-paho-mqtt -y 
    sudo apt install python3-websockets libubertooth-dev libbtbb-dev -y

    echo "${green}###############################################################################${reset}"
    echo "${green} Installing GQRX${reset}"
    echo "${green}###############################################################################${reset}"
    sudo apt-get install software-properties-common
    sudo apt-get install python3-launchpadlib
    sudo apt-get install gqrx-sdr -y

    echo "${green}###############################################################################${reset}"
    echo "${green} Installing GQRX${reset}"
    echo "${green}###############################################################################${reset}"
    sudo apt install kismet -y
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Metasploit suite${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
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

f_linux_nx() {
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing NoMachine NX client${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  	wget -P $HOME https://web9001.nomachine.com/download/9.6/Linux/nomachine_9.6.3_1_amd64.deb  
    sudo dpkg -i $HOME/nomachine_9.6.3_1_amd64.deb
    rm -rf $HOME/nomachine_9.6.3_1_amd64.deb
  fi
}

f_linux_antigravity() {
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Google Antigravity${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo -e "${green}=== Starting Google Antigravity 2.0 Installation ===${NC}"
    # 1. Clean up legacy 1.x installations to avoid redirect loops
    echo -e "${green}[1/5] Checking and cleaning up legacy 1.x installations...${NC}"
    if dpkg -l | grep -q "^ii  antigravity "; then
        echo "Found legacy antigravity apt package. Purging to prevent conflict loops..."
        sudo apt purge -y antigravity
    fi
    sudo rm -f /usr/share/applications/antigravity.desktop
    sudo rm -f /etc/apt/sources.list.d/antigravity.list
    # 2. Verify dependencies
    echo -e "${green}[2/5] Checking system dependencies...${NC}"
    DEPS=(curl wget tar xdg-utils desktop-file-utils)
    MISSING_DEPS=()
    for dep in "${DEPS[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            MISSING_DEPS+=("$dep")
        fi
    done
    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        echo "Installing missing dependencies: ${MISSING_DEPS[*]}"
        sudo apt update
        sudo apt install -y "${MISSING_DEPS[@]}"
    else
        echo "All basic dependencies met."
    fi
    # Install common system library dependencies needed by Electron runtimes
    echo "Installing common libraries required by Electron..."
    sudo apt install -y libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2t64
    # 3. Install Antigravity CLI (agy)
    echo -e "${green}[3/5] Installing Antigravity CLI (agy)...${NC}"
    curl -fsSL https://antigravity.google/cli/install.sh | bash
    # 4. Install Antigravity 2.0 Desktop Application
    echo -e "${green}[4/5] Installing Antigravity 2.0 Desktop App...${NC}"
    INSTALL_DIR="$HOME/.local/share/antigravity"
    mkdir -p "$INSTALL_DIR"
    # Detect architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        DOWNLOAD_URL="https://antigravity.google/download/linux/x64/antigravity-desktop-latest.tar.gz"
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        DOWNLOAD_URL="https://antigravity.google/download/linux/arm64/antigravity-desktop-latest.tar.gz"
    else
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
    fi
    echo "Downloading from $DOWNLOAD_URL..."
    TMP_TAR=$(mktemp /tmp/antigravity-XXXXXX.tar.gz)
    if wget -O "$TMP_TAR" "$DOWNLOAD_URL"; then
        echo "Extracting to $INSTALL_DIR..."
        tar -xzf "$TMP_TAR" -C "$INSTALL_DIR" --strip-components=1
        rm -f "$TMP_TAR"
    else
        echo -e "${RED}Failed to download the desktop package. Please ensure the link is reachable.${NC}"
        rm -f "$TMP_TAR"
        exit 1
    fi
    # Make binaries executable
    chmod +x "$INSTALL_DIR/antigravity"
    if [ -f "$INSTALL_DIR/chrome-sandbox" ]; then
        chmod +x "$INSTALL_DIR/chrome-sandbox"
    fi
    # 5. Create Desktop Launcher (LXQt Integration)
    echo -e "${green}[5/5] Creating Desktop Launcher...${NC}"
    
    LAUNCHER_PATH="$HOME/.local/share/applications/google-antigravity.desktop"
    # By default, we launch with --no-sandbox to handle Ubuntu 24.04/26.04 user namespace restrictions.
cat <<EOF > "$LAUNCHER_PATH"
[Desktop Entry]
Name=Google Antigravity
Comment=Agentic Development Platform
Exec="$INSTALL_DIR/antigravity" --no-sandbox %U
Icon=$INSTALL_DIR/resources/app/assets/icon.png
Terminal=false
Type=Application
Categories=Development;IDE;
MimeType=x-scheme-handler/antigravity;
EOF
    # Find dynamic icon fallback if the default assets folder differs
    ICON_FIND=$(find "$INSTALL_DIR" -name "*.png" -o -name "*.svg" | head -n 1)
    if [ -n "$ICON_FIND" ]; then
        sed -i "s|Icon=.*|Icon=$ICON_FIND|" "$LAUNCHER_PATH"
    fi
    
    chmod +x "$LAUNCHER_PATH"
    update-desktop-database "$HOME/.local/share/applications"
    
    echo -e "${GREEN}=== Installation Completed Successfully! ===${NC}"
    echo -e "You can launch Google Antigravity from the Lubuntu Application Menu (under Development)."
    echo -e "Or run it from the terminal using:"
    echo -e "  $INSTALL_DIR/antigravity --no-sandbox"
    echo -e ""
    echo -e "To initialize the CLI, reload your shell and log in:"
    echo -e "  source ~/.bashrc"
    echo -e "  agy auth login"
    echo -e ""
    echo -e "${green}NOTE regarding Ubuntu/Lubuntu 26.04 Sandboxing:${NC}"
    echo -e "The launcher uses '--no-sandbox' because Ubuntu 26.04 restricts unprivileged user namespaces."
    echo -e "If you prefer running with the sandbox enabled, allow user namespaces system-wide:"
    echo -e "  sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0"
    echo -e "To make this configuration persistent across reboots, run:"
    echo -e "  echo 'kernel.apparmor_restrict_unprivileged_userns = 0' | sudo tee /etc/sysctl.d/60-apparmor-namespace.conf"
    echo -e "Then, you can remove '--no-sandbox' from $LAUNCHER_PATH."
  fi
}

f_linux_vscode() {
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing VS Code${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    #sudo apt install software-properties-common apt-transport-https wget -y
    sudo apt install apt-transport-https wget -y
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg 
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    sudo apt update
    sudo apt install code -y
  fi
}

f_linux_vpns() {
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Netbird client${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sudo apt-get install ca-certificates curl gnupg -y
    curl -sSL https://pkgs.netbird.io/debian/public.key | sudo gpg --dearmor --output /usr/share/keyrings/netbird-archive-keyring.gpg
    echo 'deb [signed-by=/usr/share/keyrings/netbird-archive-keyring.gpg] https://pkgs.netbird.io/debian stable main' | sudo tee /etc/apt/sources.list.d/netbird.list
    sudo apt-get update
    sudo apt-get install netbird -y
    sudo apt-get install netbird-ui -y
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Forticlient${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    wget -O - https://repo.fortinet.com/repo/forticlient/7.4/ubuntu22/DEB-GPG-KEY | gpg --dearmor | sudo tee /usr/share/keyrings/repo.fortinet.com.gpg   
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/repo.fortinet.com.gpg] https://repo.fortinet.com/repo/forticlient/7.4/ubuntu22/ stable non-free" | sudo tee /etc/apt/sources.list.d/repo.fortinet.com.list
    sudo apt update   
    sudo apt install forticlient -y
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing ProtonVPN Client${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    wget https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb
    sudo dpkg -i ./protonvpn-stable-release_1.0.8_all.deb && sudo apt update
    sudo apt install proton-vpn-gnome-desktop -y
    sudo apt install gnome-shell-extension-appindicator -y
    sudo rm -rf ./protonvpn-stable-release_1.0.8_all.deb
  fi
}

f_linux_config_apps(){
  echo "${green}###############################################################################${reset}"
  echo "${green} Copying Configuration Files (vim, tmux, kitty, git)${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    # for vim
    echo "${green}###############################################################################${reset}"
    echo "${green} Configuring VIM${reset}"
    echo "${green}###############################################################################${reset}"
    rm -rf $HOME/.vimrc
    ln -s $HOME/init_setup/config/vim/vimrc $HOME/.vimrc

    # for tmux
    echo "${green}###############################################################################${reset}"
    echo "${green} Configuring TMUX${reset}"
    echo "${green}###############################################################################${reset}"
    rm -rf $HOME/.tmux.conf
    ln -s $HOME/init_setup/config/tmux/tmux.conf $HOME/.tmux.conf

    # for kitty config
    echo "${green}###############################################################################${reset}"
    echo "${green} Configuring KITTY${reset}"
    echo "${green}###############################################################################${reset}"
    rm -rf $HOME/.config/kitty/kitty.conf
    mkdir -p $HOME/.config/kitty
    ln -s $HOME/init_setup/config/kitty/kitty.conf $HOME/.config/kitty/kitty.conf

    echo "${green}###############################################################################${reset}"
    echo "${green} Installing TMUX pluggings${reset}"
    echo "${green}###############################################################################${reset}"
    # Plugin Manager - https://github.com/tmux-plugins/tpm
    # If you didn't use my dotfiles install script you'll need to:
    rm -rf ~/.tmux/plugins/tpm
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

    # for git config
    echo "${green}###############################################################################${reset}"
    echo "${green} Configuring Git${reset}"
    echo "${green}###############################################################################${reset}"
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
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Desktop Packages${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    f_linux_desktop_packages  
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing Server Packages${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    f_linux_server_packages  
  fi
  echo "${green}###############################################################################${reset}"
  echo "${green} Installing VPNs clients${reset}"
  echo "${green}###############################################################################${reset}"
  read -r -p "Continue? [y/N]" -n 1
  echo # (optional) move to a new line
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    f_linux_vpns
  fi
  f_linux_config_apps
  f_linux_nx
  f_linux_vscode
  f_linux_antigravity

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
