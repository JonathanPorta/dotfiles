#!/bin/bash
set -e
command -v curl >/dev/null 2>&1 || { echo "I require curl but it's not installed.  Aborting." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "I require jq but it's not installed.  Aborting." >&2; exit 1; }

# Make my typical devel directory
export DEVEL="$HOME/devel/portaj"
export DOTFILES_CHECKOUT="$DEVEL/dotfiles"
mkdir -p $DEVEL

# we want to be able to run this and update the authorized keys with whatever we have on GH
curl https://api.github.com/users/jonathanporta/keys | jq -r '.[] | .key' > $HOME/.ssh/authorized_keys
# echo "Updated '$HOME/.ssh/authorized_keys' to:"
# cat $HOME/.ssh/authorized_keys
echo "Truncated and wrote $(cat $HOME/.ssh/authorized_keys | wc -l) keys to '$HOME/.ssh/authorized_keys'."

# Link the SSH config to the dotfiles repo
if [ ! -f "$HOME/.ssh/config" ]; then
  ln -s "$HOME/dotfiles/ssh-config" "$HOME/.ssh/config"
else
  echo "'$HOME/.ssh/config' already exists - not linking to '$HOME/dotfiles/ssh-config'."
fi
chmod 400 $HOME/.ssh/config

# If .secrets hasn't been created create a blank one
if [ ! -f "$HOME/dotfiles/.secrets" ]; then
  cp "$HOME/dotfiles/.secrets-example" "$HOME/dotfiles/.secrets"
else
  echo "'$HOME/dotfiles/.secrets' already exists - not copying a blank one."
fi
chmod 500 $HOME/dotfiles/.secrets

# Replace existing .zshrc in $HOME with a link to our dotfile version
if [ -f "$HOME/.zshrc" ]; then
  echo "'$HOME/.zshrc' already exists - renaming to '$HOME/.zshrc.old' and linking to '$HOME/dotfiles/.zshrc'."
  mv "$HOME/.zshrc" "$HOME/.zshrc.old"
fi
ln -s "$HOME/dotfiles/.zshrc" "$HOME/.zshrc"

# Replace existing .gitconfig in $HOME with a link to our dotfile version
if [ -f "$HOME/.gitconfig" ]; then
  echo "'$HOME/.gitconfig' already exists - renaming to '$HOME/.gitconfig.old' and linking to '$HOME/dotfiles/.gitconfig'."
  mv "$HOME/.gitconfig" "$HOME/.gitconfig.old"
fi
ln -s "$HOME/dotfiles/.gitconfig" "$HOME/.gitconfig"

# Replace existing .gitignore_global in $HOME with a link to our dotfile version
if [ -f "$HOME/.gitignore_global" ]; then
  echo "'$HOME/.gitignore_global' already exists - renaming to '$HOME/.gitignore_global.old' and linking to '$HOME/dotfiles/.gitignore_global'."
  mv "$HOME/.gitignore_global" "$HOME/.gitignore_global.old"
fi
ln -s "$HOME/dotfiles/.gitignore_global" "$HOME/.gitignore_global"

# Replace existing .chruby in $HOME with a link to our dotfile version
if [ -f "$HOME/.chruby" ]; then
  echo "'$HOME/.chruby' already exists - renaming to '$HOME/.chruby.old' and linking to '$HOME/dotfiles/.chruby'."
  mv "$HOME/.chruby" "$HOME/.chruby.old"
fi
ln -s "$HOME/dotfiles/.chruby" "$HOME/.chruby"

# Get ZSH ready
if [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
  echo "'$HOME/.oh-my-zsh/oh-my-zsh.sh' already exists - renaming to '$HOME/.oh-my-zsh.old' and installing oh-my-zsh"
  mv "$HOME/.oh-my-zsh" "$HOME/.oh-my-zsh.old$(date -u +%s)"
fi
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
export ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
$DOTFILES_CHECKOUT/installation/oh-my-zsh.sh

# source $HOME/.zshrc
chsh -s $(which zsh)
# sudo chsh -s $(which zsh) ## For root

# Doing these first for some reason.
# $DOTFILES_CHECKOUT/installation/node.sh
# $DOTFILES_CHECKOUT/installation/ruby.sh
# $DOTFILES_CHECKOUT/installation/vim.sh

echo "Installing applications..."
echo "About to run '$DOTFILES_CHECKOUT/installation/all.sh'."
$DOTFILES_CHECKOUT/installation/all.sh
