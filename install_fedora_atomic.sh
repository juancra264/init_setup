#!/usr/bin/env bash
set -e

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
## Setting up local directories
# #############################################################################
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.ssh"

#setting SSH keys
KEY_PATH="$HOME/.ssh/juan_key"

if [ -f "$KEY_PATH" ]; then
  echo "${green}✓ SSH key already exists${reset}"
else
  echo "${red}✗ Generating Ed25519 key${reset}"
  ssh-keygen -t ed25519 -N "" -f "$KEY_PATH" -C "automated_deploy"
  ssh-keygen -t ed25519 -a 100 -N "" -f $HOME/.ssh/juan_key -C "juancra264@gmail.com"
  chmod 700 $HOME/.ssh
  chmod 600 $HOME/.ssh/juan_key
  chmod 644 $HOME/.ssh/juan_key.pub
  eval "$(ssh-agent -s)"
  ssh-add $HOME/.ssh/juan_key
  cat <<'EOF' >>$HOME/.ssh/config
Host *
    HostkeyAlgorithms +ssh-rsa
    KexAlgorithms +diffie-hellman-group14-sha1
    IdentityFile ~/.ssh/juan_key
EOF
fi

# Installing Nerdfonts for LazyVim
if fc-list : family | grep -iq "nerd font"; then
  echo "${green}✓ Nerd Font is installed${reset}"
else
  echo "${red}✗ No Nerd Font found${reset}"
  mkdir -p ~/.local/share/fonts
  curl -fLo /tmp/JetBrainsMono.tar.xz https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
  tar -xf /tmp/JetBrainsMono.tar.xz -C ~/.local/share/fonts/
  rm /tmp/JetBrainsMono.tar.xz
  fc-cache -fv
fi

# 1. Check and Install Prerequisites via rpm-ostree if missing
# Note: Fedora Atomic requires a reboot for rpm-ostree packages. If neovim/git aren't installed,
# we will prompt or install them.
MISSING_PKGS=()
if ! command -v btop &>/dev/null; then MISSING_PKGS+=("btop"); fi
if ! command -v fastfetch &>/dev/null; then MISSING_PKGS+=("fastfetch"); fi
if ! command -v gcc &>/dev/null; then MISSING_PKGS+=("gcc"); fi
if ! command -v gparted &>/dev/null; then MISSING_PKGS+=("gparted"); fi
if ! command -v make &>/dev/null; then MISSING_PKGS+=("make"); fi
if ! command -v mosh &>/dev/null; then MISSING_PKGS+=("mosh"); fi
if ! command -v vim &>/dev/null; then MISSING_PKGS+=("vim-enhanced"); fi
if ! command -v zsh &>/dev/null; then MISSING_PKGS+=("zsh"); fi
if ! command -v alacritty &>/dev/null; then MISSING_PKGS+=("alacritty"); fi
if ! command -v nvim &>/dev/null; then MISSING_PKGS+=("neovim"); fi
if ! command -v git &>/dev/null; then MISSING_PKGS+=("git"); fi
if ! command -v rg &>/dev/null; then MISSING_PKGS+=("ripgrep"); fi
if ! command -v fd &>/dev/null; then MISSING_PKGS+=("fd-find"); fi
if ! command -v ncdu &>/dev/null; then MISSING_PKGS+=("ncdu"); fi
if ! command -v foot &>/dev/null; then MISSING_PKGS+=("foot"); fi
if ! command -v zoxide &>/dev/null; then MISSING_PKGS+=("zoxide"); fi
if ! &>/dev/null; then MISSING_PKGS+=("ncdu"); fi
if ! command -v ncdu &>/dev/null; then MISSING_PKGS+=("ncdu"); fi

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
  echo "📦 The following required packages are missing: ${MISSING_PKGS[*]}"
  echo "Installing via rpm-ostree (this may require your sudo password and a system reboot)..."
  sudo rpm-ostree install -y "${MISSING_PKGS[@]}"

  echo ""
  echo "⚠️  NOTE: Since you are on Fedora Atomic, rpm-ostree packages require a reboot to take effect."
  echo "Please reboot your system after this script finishes, then run Neovim to let LazyVim bootstrap plugins."
else
  echo "${green}✓ rpm-ostree prerequisites installed${reset}"
fi

# Installing Cliamp
curl -fsSL https://cliamp.stream/install.sh | sh

#Install zsh-syntax-highlighting
PACKAGE="zsh-syntax-highlighting"
# Check if the package is already layered or present in the base image
if rpm -q "$PACKAGE" &>/dev/null; then
  echo "${green}✓ $PACKAGE is already installed.${reset}"
else
  echo "${blue}$PACKAGE is not installed. Layering package via rpm-ostree...${reset}"
  rpm-ostree install -y "$PACKAGE"
fi

#Install zsh-autosuggestions
PACKAGE="zsh-autosuggestions"
# Check if the package is already layered or present in the base image
if rpm -q "$PACKAGE" &>/dev/null; then
  echo "${green}✓ $PACKAGE is already installed.${reset}"
else
  echo "${blue}$PACKAGE is not installed. Layering package via rpm-ostree...${reset}"
  rpm-ostree install -y "$PACKAGE"
fi

#Setting flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

flatpak install flathub app.zen_browser.zen -uy
flatpak install flathub com.brave.Browser -uy
flatpak install flathub md.obsidian.Obsidian -uy
flatpak install flathub org.kicad.KiCad -uy
flatpak install flathub com.obsproject.Studio -uy
flatpak install flathub org.flameshot.Flameshot -uy
flatpak install flathub com.github.unrud.VideoDownloader -uy
flatpak install flathub org.audacityteam.Audacity -uy
flatpak install flathub com.vivaldi.Vivaldi -uy
flatpak install flathub com.jgraph.drawio.desktop -uy
flatpak install flathub com.yubico.yubioath -uy
flatpak install flathub org.remmina.Remmina -uy
flatpak install flathub org.videolan.VLC -uy
flatpak install flathub org.gnome.Loupe -uy

# Herdr
if (command -v herdr || which herdr); then
  echo "${green}✓ Herdr is installed${reset}"
else
  echo "${red}✗ Herdr not found${reset}"
  #Download and install Herdr using the official installer script
  echo "${blue}📥 Downloading and installing Herdr...${reset}"
  curl -fsSL https://herdr.dev/install.sh | sh
fi

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi
# Install zsh plugins
echo "${green}####################################################${reset}"
echo "${green} Installing zsh plugins zsh-syntax-highlighting ${reset}"
echo "${green}####################################################${reset}"
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi
echo "${green}####################################################${reset}"
echo "${green} Installing zsh plugins zsh-syntax-autosuggestions${reset}"
echo "${green}####################################################${reset}"
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
fi
# Install nettools
echo "${green}####################################################${reset}"
echo "${green} Installing Nettools${reset}"
echo "${green}####################################################${reset}"
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
echo "${green}####################################################${reset}"
echo "${green} Configuring zshrc${reset}"
echo "${green}####################################################${reset}"
rm -rf $HOME/.zshrc
cp $HOME/init_setup/config/zshrc_fedora/zshrc $HOME/.zshrc

# Install starship
echo "${green}####################################################${reset}"
echo "${green} Installing starship ${reset}"
echo "${green}####################################################${reset}"
if command -v starship &>/dev/null; then
  echo "Starship is installed!"
else
  echo "Starship is not installed."
  curl -sS https://starship.rs/install.sh | sh
  echo 'eval "$(starship init zsh)"' >>~/.zshrc
fi

# for git config
echo "${green}###############################################################################${reset}"
echo "${green} Configuring Git${reset}"
echo "${green}###############################################################################${reset}"
rm -rf $HOME/.gitconfig
ln -s $HOME/init_setup/config/git/gitconfig $HOME/.gitconfig
git config --global user.name "juancra264"
git config --global user.email "juancra264@gmail.com"
git config --global user.username "juancra264"

# for starship
echo "${green}###############################################################################${reset}"
echo "${green} Configuring starship${reset}"
echo "${green}###############################################################################${reset}"
rm -rf $HOME/.config/starship.toml
ln -s $HOME/init_setup/config/starship/starship.toml $HOME/.config/starship.toml

# configuring foot
mkdir -p ~/.config/foot
cp /etc/xdg/foot/foot.ini ~/.config/foot/foot.ini

# for alacritty
echo "${green}###############################################################################${reset}"
echo "${green} Configuring Alacritty${reset}"
echo "${green}###############################################################################${reset}"
rm -rf $HOME/.config/alacritty/alacritty.toml
mkdir -p $HOME/.config/alacritty/
ln -s $HOME/init_setup/config/alacritty/alacritty.toml $HOME/.config/alacritty/alacritty.toml

echo "${green}###############################################################################${reset}"
echo "${green} Configuring VIM${reset}"
echo "${green}###############################################################################${reset}"
rm -rf $HOME/.vimrc
ln -s $HOME/init_setup/config/vim/vimrc $HOME/.vimrc

echo "${green}######################################################${reset}"
echo "${green} Installing LazzyVim${reset}"
echo "${green}######################################################${reset}"
read -r -p "Continue? [y/N]" -n 1
echo # (optional) move to a new line
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  echo "installing Lazyvim"
  # Backup existing Neovim files if they exist
  echo "backup existing Neovim configurations..."
  [ -d "$HOME/.config/nvim" ] && mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%Y%m%d_%H%M%S)"
  [ -d "$HOME/.local/share/nvim" ] && mv "$HOME/.local/share/nvim" "$HOME/.local/share/nvim.bak.$(date +%Y%m%d_%H%M%S)"
  [ -d "$HOME/.local/state/nvim" ] && mv "$HOME/.local/state/nvim" "$HOME/.local/state/nvim.bak.$(date +%Y%m%d_%H%M%S)"
  [ -d "$HOME/.cache/nvim" ] && mv "$HOME/.cache/nvim" "$HOME/.cache/nvim.bak.$(date +%Y%m%d_%H%M%S)"

  # Neovim (Linux x86_64 AppImage/tarball)
  if ! command -v nvim &>/dev/null; then
    echo "Installing Neovim..."
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    tar -xzf nvim-linux-x86_64.tar.gz
    install -m 755 nvim-linux-x86_64/bin/nvim "$HOME/.local/bin/nvim"
    rm -rf nvim-linux-x86_64 nvim-linux-x86_64.tar.gz
  else
    echo "Neovim already installed."
  fi

  # Lazygit
  if ! command -v lazygit &>/dev/null; then
    echo "Installing Lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    install -m 755 lazygit "$HOME/.local/bin/lazygit"
    rm lazygit lazygit.tar.gz
  else
    echo "Lazygit already installed."
  fi

  # Ripgrep (rg)
  if ! command -v rg &>/dev/null; then
    echo "Installing Ripgrep..."
    RG_VERSION=$(curl -s "https://api.github.com/repos/BurntSushi/ripgrep/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
    curl -Lo ripgrep.tar.gz "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-x86_64-unknown-linux-musl.tar.gz"
    tar -xzf ripgrep.tar.gz
    install -m 755 ripgrep-${RG_VERSION}-x86_64-unknown-linux-musl/rg "$HOME/.local/bin/rg"
    rm -rf ripgrep-${RG_VERSION}-x86_64-unknown-linux-musl ripgrep.tar.gz
  else
    echo "Ripgrep already installed."
  fi

  # fd-find (fd)
  if ! command -v fd &>/dev/null; then
    echo "Installing fd..."
    FD_VERSION=$(curl -s "https://api.github.com/repos/sharkdp/fd/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo fd.tar.gz "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-x86_64-unknown-linux-musl.tar.gz"
    tar -xzf fd.tar.gz
    install -m 755 fd-v${FD_VERSION}-x86_64-unknown-linux-musl/fd "$HOME/.local/bin/fd"
    rm -rf fd-v${FD_VERSION}-x86_64-unknown-linux-musl fd.tar.gz
  else
    echo "fd already installed."
  fi

  echo "=== 3. Backing up existing Neovim configs (if any) ==="
  for dir in nvim share/nvim state/nvim cache/nvim; do
    if [ -d "$HOME/.local/$dir" ] || [ -d "$HOME/.config/nvim" ]; then
      [ -e "$HOME/.config/nvim" ] && mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%Y%m%d_%H%M%S)"
    fi
  done

  echo "=== 4. Cloning LazyVim starter repo ==="
  if [ ! -d "$HOME/.config/nvim" ]; then
    git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
    rm -rf "$HOME/.config/nvim/.git"
  else
    echo "~/.config/nvim already exists. Skipping clone."
  fi

  # Configure Zsh integration (ensure local bin paths are available if needed)
  ZSHRC="$HOME/.zshrc"
  echo "⚙️ Configuring Zsh environment..."

  if [ -f "$ZSHRC" ]; then
    # Ensure ~/.local/bin is in PATH for Zsh users
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$ZSHRC"; then
      echo '' >>"$ZSHRC"
      echo '# Added by Apps installer' >>"$ZSHRC"
      echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$ZSHRC"
    fi

    # Optional: Add a convenient alias for nvim
    if ! grep -q 'alias v="nvim"' "$ZSHRC"; then
      echo 'alias v="nvim"' >>"$ZSHRC"
    fi
  fi
fi

echo ""
echo " ${green}✓ Setup Done successfully!${reset}"
echo "------------------------------------------------------------------"
echo "Next Steps:"
echo "If packages were installed via rpm-ostree, reboot your system now:"
echo "   \$ systemctl reboot"
echo "------------------------------------------------------------------"
