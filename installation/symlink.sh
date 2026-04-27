#!/usr/bin/env bash

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

# Replace existing .zshenv in $HOME with a link to our dotfile version
echo "Ensure symlink of '$HOME/.zshenv' points to '$HOME/dotfiles/.zshenv'..."
if [ -f "$HOME/.zshenv" ]; then
  echo "'$HOME/.zshenv' already exists - renaming to '$HOME/.zshenv.old$NOW' and linking to '$HOME/dotfiles/.zshenv'."
  mv "$HOME/.zshenv" "$HOME/.zshenv.old$NOW"
fi
ln -s "$HOME/dotfiles/.zshenv" "$HOME/.zshenv"

# Replace existing .zprofile in $HOME with a link to our dotfile version
echo "Ensure symlink of '$HOME/.zprofile' points to '$HOME/dotfiles/.zprofile'..."
if [ -f "$HOME/.zprofile" ]; then
  echo "'$HOME/.zprofile' already exists - renaming to '$HOME/.zprofile.old$NOW' and linking to '$HOME/dotfiles/.zprofile'."
  mv "$HOME/.zprofile" "$HOME/.zprofile.old$NOW"
fi
ln -s "$HOME/dotfiles/.zprofile" "$HOME/.zprofile"

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

# Link the helpers directory to $HOME/.helpers
echo "Ensure symlink of '$HOME/.helpers' points to '$HOME/dotfiles/helpers'..."
if [ -L "$HOME/.helpers" ] && [ "$(readlink "$HOME/.helpers")" = "$HOME/dotfiles/helpers" ]; then
  echo "'$HOME/.helpers' already points to '$HOME/dotfiles/helpers' - nothing to do."
elif [ -e "$HOME/.helpers" ] || [ -L "$HOME/.helpers" ]; then
  echo "WARNING: '$HOME/.helpers' exists but does not point to '$HOME/dotfiles/helpers' - relinking."
  mv "$HOME/.helpers" "$HOME/.helpers.old$NOW"
  ln -s "$HOME/dotfiles/helpers" "$HOME/.helpers"
else
  ln -s "$HOME/dotfiles/helpers" "$HOME/.helpers"
fi

# cmux settings + custom notification sound
echo "Ensure '$HOME/.sounds' and '$HOME/.config/cmux' exist..."
mkdir -p "$HOME/.sounds" "$HOME/.config/cmux"

echo "Ensure symlink of '$HOME/.sounds/cmux-notification.wav' points to '$HOME/dotfiles/cmux-notification.wav'..."
if [ -L "$HOME/.sounds/cmux-notification.wav" ] && [ "$(readlink "$HOME/.sounds/cmux-notification.wav")" = "$HOME/dotfiles/cmux-notification.wav" ]; then
  echo "'$HOME/.sounds/cmux-notification.wav' already points to '$HOME/dotfiles/cmux-notification.wav' - nothing to do."
elif [ -e "$HOME/.sounds/cmux-notification.wav" ] || [ -L "$HOME/.sounds/cmux-notification.wav" ]; then
  echo "WARNING: '$HOME/.sounds/cmux-notification.wav' exists but does not point to '$HOME/dotfiles/cmux-notification.wav' - relinking."
  mv "$HOME/.sounds/cmux-notification.wav" "$HOME/.sounds/cmux-notification.wav.old$NOW"
  ln -s "$HOME/dotfiles/cmux-notification.wav" "$HOME/.sounds/cmux-notification.wav"
else
  ln -s "$HOME/dotfiles/cmux-notification.wav" "$HOME/.sounds/cmux-notification.wav"
fi

echo "Rendering '$HOME/.config/cmux/settings.json' from template..."
"$HOME/dotfiles/helpers/generate_cmux_settings.sh"

# GPG configuration is handled by installation/gpg.sh
