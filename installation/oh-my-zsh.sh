#!/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
# set -e


# OhMyZSH plugins
echo_green "Installing OhMyZSH customizations..."
source $HOME/.zshrc
git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
echo_green "Done."

# change default shell
echo_green "Setting zsh to default shell..."
source $HOME/.zshrc
chsh -s $(which zsh)
sudo chsh -s $(which zsh) # Set root user to use ZSH.
source $HOME/.zshrc
echo_green "Done."
set -e
