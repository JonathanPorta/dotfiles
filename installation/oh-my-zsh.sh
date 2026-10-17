#!/usr/bin/env zsh

set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
# set -e

if [ -d "$HOME/.oh-my-zsh" ]; then
  echo_cyan "'$HOME/.oh-my-zsh' already exists. Skipping..."
else
  echo_green "Installing oh-my-zsh..."
  source $HOME/.zshrc
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  source $HOME/.zshrc
  echo_green "Done."
fi

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
# Each step is skipped when its result already exists, so re-runs stay quiet.
[ -d "$ZSH_CUSTOM/themes/spaceship-prompt" ] || git clone https://github.com/denysdovhan/spaceship-prompt.git --branch v4.21.1 "$ZSH_CUSTOM/themes/spaceship-prompt"
[ -L "$ZSH_CUSTOM/themes/spaceship.zsh-theme" ] || ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
[ -d "$ZSH_CUSTOM/plugins/zsh-completions" ] || git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
[ -d "$ZSH_CUSTOM/plugins/dogesay" ] || git clone https://github.com/txstc55/dogesay "$ZSH_CUSTOM/plugins/dogesay"
source $HOME/.zshrc
echo_green "Done."

# change default shell
echo_green "Setting zsh to default shell..."
source $HOME/.zshrc
# Resolve the desired login shell and the one currently on record. Reading the
# current shell needs no privileges (dscl/getent), so we can check first and
# only `sudo chsh` when it would actually change something — otherwise a
# re-run prompts for a sudo password just to set the shell to what it already is.
# Use /bin/zsh on macOS to avoid /etc/shells issues with Homebrew zsh.
if [ "$(uname -s)" = "Darwin" ]; then
  desired_shell="/bin/zsh"
  current_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
else
  desired_shell="$(command -v zsh)"
  current_shell="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)"
fi
if [ "$current_shell" = "$desired_shell" ]; then
  echo_green "Default shell is already '$desired_shell' - skipping chsh (no password needed)."
else
  sudo chsh -s "$desired_shell" "$USER"
fi
source $HOME/.zshrc
echo_green "Done."
set -e
