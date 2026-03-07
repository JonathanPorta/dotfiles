#!/usr/bin/env zsh

set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
# set -e

echo_green "Installing oh-my-zsh..."
source $HOME/.zshrc
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
source $HOME/.zshrc
echo_green "Done."

# Do this again because oh-my-zsh removes it
# Replace existing .zshrc in $HOME with a link to our dotfile version
echo_green "Ensure symlink of '$HOME/.zshrc' points to '$HOME/dotfiles/.zshrc'..."
if [ -f "$HOME/.zshrc" ]; then
  echo_green "'$HOME/.zshrc' already exists - renaming to '$HOME/.zshrc.old$NOW' and linking to '$HOME/dotfiles/.zshrc'."
  mv "$HOME/.zshrc" "$HOME/.zshrc.old$NOW"
fi
ln -s "$HOME/dotfiles/.zshrc" "$HOME/.zshrc"

# OhMyZSH plugins
echo_green "Installing oh-my-zsh customizations..."
source $HOME/.zshrc
git clone https://github.com/denysdovhan/spaceship-prompt.git --branch v4.21.1 "$ZSH_CUSTOM/themes/spaceship-prompt"
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
git clone https://github.com/txstc55/dogesay "$ZSH_CUSTOM/plugins/
source $HOME/.zshrc
echo_green "Done."

# change default shell
echo_green "Setting zsh to default shell..."
source $HOME/.zshrc
if [ -f "/bin/zsh" ]; then
  echo_green "Please enter the following path: /bin/zsh"
  sudo lchsh -i $USER
  sudo lchsh -i root
else
  echo_green "Please enter the following path: $(which zsh)"
  sudo lchsh -i $USER
  sudo lchsh -i root
fi
source $HOME/.zshrc
echo_green "Done."
set -e
