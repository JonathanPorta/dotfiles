#!/bin/zsh
set +e

echo "Install Oh My ZSH customizations"
git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"

source $HOME/.zshrc
chsh -s $(which zsh)
sudo chsh -s $(which zsh)
source $HOME/.zshrc
set -e
