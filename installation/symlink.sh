#!/bin/bash
set -e
source $(cd $(dirname "$0") && pwd)/include/vars.sh


echo "Beginning symlinkage of select dotfiles in '$HOME' to '$DOTFILES_CHECKOUT'..."

# Link the SSH config to the dotfiles repo
echo "Ensure symlink of '$HOME/.ssh/config' points to '$HOME/dotfiles/ssh-config'..."
if [ ! -f "$HOME/.ssh/config" ]; then
  ln -s "$HOME/dotfiles/ssh-config" "$HOME/.ssh/config"
else
  echo "'$HOME/.ssh/config' already exists - not linking to '$HOME/dotfiles/ssh-config'."
fi
chmod 400 $HOME/.ssh/config

# If .secrets hasn't been created create a blank one
echo "Ensure symlink of '$HOME/.secrets' points to '$HOME/dotfiles/.secrets'..."
if [ ! -f "$HOME/dotfiles/.secrets" ]; then
  cp "$HOME/dotfiles/.secrets-example" "$HOME/dotfiles/.secrets"
else
  echo "'$HOME/dotfiles/.secrets' already exists - not copying a blank one."
fi
chmod 500 $HOME/dotfiles/.secrets

# Replace existing .zshrc in $HOME with a link to our dotfile version
echo "Ensure symlink of '$HOME/.zshrc' points to '$HOME/dotfiles/.zshrc'..."
if [ -f "$HOME/.zshrc" ]; then
  echo "'$HOME/.zshrc' already exists - renaming to '$HOME/.zshrc.old$NOW' and linking to '$HOME/dotfiles/.zshrc'."
  mv "$HOME/.zshrc" "$HOME/.zshrc.old$NOW"
fi
ln -s "$HOME/dotfiles/.zshrc" "$HOME/.zshrc"

# Replaced linking of $HOME/.gitconfig with generate_gitconfig.sh, make sure there isn't one already.
echo "Removing '$HOME/.gitconfig'..."
if [ -f "$HOME/.gitconfig" ]; then
  mv "$HOME/.gitconfig" "$HOME/.gitconfig.old$NOW"
fi

# Replace existing .gitignore_global in $HOME with a link to our dotfile version
echo "Ensure symlink of '$HOME/.gitignore_global' points to '$HOME/dotfiles/.gitignore_global'..."
if [ -f "$HOME/.gitignore_global" ]; then
  echo "'$HOME/.gitignore_global' already exists - renaming to '$HOME/.gitignore_global.old$NOW' and linking to '$HOME/dotfiles/.gitignore_global'."
  mv "$HOME/.gitignore_global" "$HOME/.gitignore_global.old$NOW"
fi
ln -s "$HOME/dotfiles/.gitignore_global" "$HOME/.gitignore_global"

# Replace existing .chruby in $HOME with a link to our dotfile version
echo "Ensure symlink of '$HOME/.chruby' points to '$HOME/dotfiles/.chruby'..."
if [ -f "$HOME/.chruby" ]; then
  echo "'$HOME/.chruby' already exists - renaming to '$HOME/.chruby.old$NOW' and linking to '$HOME/dotfiles/.chruby'."
  mv "$HOME/.chruby" "$HOME/.chruby.old$NOW"
fi
ln -s "$HOME/dotfiles/.chruby" "$HOME/.chruby"

# Get ZSH ready
if [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
  echo "'$HOME/.oh-my-zsh/oh-my-zsh.sh' already exists - renaming to '$HOME/.oh-my-zsh.old$NOW'..."
  mv "$HOME/.oh-my-zsh" "$HOME/.oh-my-zsh.old$NOW"
fi

# Do this again because oh-my-zsh removes it
# Replace existing .zshrc in $HOME with a link to our dotfile version
echo "Ensure symlink of '$HOME/.zshrc' points to '$HOME/dotfiles/.zshrc'..."
if [ -f "$HOME/.zshrc" ]; then
  echo "'$HOME/.zshrc' already exists - renaming to '$HOME/.zshrc.old$NOW' and linking to '$HOME/dotfiles/.zshrc'."
  mv "$HOME/.zshrc" "$HOME/.zshrc.old$NOW"
fi
ln -s "$HOME/dotfiles/.zshrc" "$HOME/.zshrc"
