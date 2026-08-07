#!/bin/bash

ZSHRC_FILE="$HOME/.zshrc"
TMP_FILE="${ZSHRC_FILE}.tmp"

# 1. Check if .zshrc exists
if [[ ! -f "$ZSHRC_FILE" ]]; then
    echo "Error: $ZSHRC_FILE does not exist."
    exit 1
fi

# 2. Create a backup just in case
cp "$ZSHRC_FILE" "${ZSHRC_FILE}.bak"
echo "Created backup at ${ZSHRC_FILE}.bak"

# 3. Process the file line by line
awk '
{
    # If the line matches exactly, prepend a "# "
    if ($0 == "source ~/powerlevel10k/powerlevel10k.zsh-theme" || 
        $0 == "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh") {
        print "# " $0
    } else {
        # Otherwise, print the line as-is
        print $0
    }
}' "$ZSHRC_FILE" > "$TMP_FILE"

# 4. Overwrite the original file with the modified version
mv "$TMP_FILE" "$ZSHRC_FILE"

echo "Successfully commented out Powerlevel10k lines in $ZSHRC_FILE."

# 5 . Install starship
curl -sS https://starship.rs/install.sh | sh
echo 'eval "$(starship init zsh)"' >> ~/.zshrc

# 6. Configure starship
rm -rf $HOME/.config/starship.toml
ln -s $HOME/init_setup/config/starship/starship.toml $HOME/.config/starship.toml

# 7. Apply changes.
source ~/.zshrc

