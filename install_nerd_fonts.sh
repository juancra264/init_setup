#!/bin/bash

# ==========================================
# Configuration
# ==========================================
# Change this to your preferred Nerd Font (e.g., FiraCode, Hack, Meslo)
FONT_NAME="JetBrainsMono"
FONT_DIR="$HOME/.local/share/fonts/$FONT_NAME"
VERSION_FILE="$FONT_DIR/.version"

# ==========================================
# 1. Dependency Check
# ==========================================
for cmd in curl unzip fc-cache; do
  if ! command -v $cmd &>/dev/null; then
    echo "Error: '$cmd' is not installed."
    echo "Please install it using: sudo apt update && sudo apt install $cmd"
    exit 1
  fi
done

# ==========================================
# 2. Check Latest Version
# ==========================================
echo "Checking GitHub for the latest Nerd Fonts release..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
  echo "Failed to fetch the latest version from GitHub API. Check your internet connection."
  exit 1
fi

echo "Latest available version: $LATEST_VERSION"

# ==========================================
# 3. Compare Local vs Latest (Upgrade Logic)
# ==========================================
if [ -d "$FONT_DIR" ] && [ -f "$VERSION_FILE" ]; then
  CURRENT_VERSION=$(cat "$VERSION_FILE")
  if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
    echo "✅ $FONT_NAME Nerd Font is already installed and up-to-date ($CURRENT_VERSION)."
    exit 0
  else
    echo "🔄 Upgrading $FONT_NAME from $CURRENT_VERSION to $LATEST_VERSION..."
  fi
else
  echo "⬇️ Installing $FONT_NAME Nerd Font ($LATEST_VERSION)..."
fi

# ==========================================
# 4. Download and Extract
# ==========================================
DOWNLOAD_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/$LATEST_VERSION/$FONT_NAME.zip"
TMP_ZIP="/tmp/${FONT_NAME}.zip"

echo "Downloading $FONT_NAME.zip..."
curl -L -o "$TMP_ZIP" "$DOWNLOAD_URL"

# Create directory if it doesn't exist
mkdir -p "$FONT_DIR"

echo "Extracting fonts to $FONT_DIR..."
# The -o flag forces unzip to overwrite existing files during an upgrade
unzip -o "$TMP_ZIP" -d "$FONT_DIR" >/dev/null

# ==========================================
# 5. Cleanup and Apply
# ==========================================
rm "$TMP_ZIP"
echo "$LATEST_VERSION" >"$VERSION_FILE"

echo "Rebuilding system font cache..."
fc-cache -f "$FONT_DIR"

echo "🎉 Success! $FONT_NAME ($LATEST_VERSION) is ready to use."
