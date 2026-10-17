#!/usr/bin/env zsh

set +e
source $(cd $(dirname "$0") && pwd)/include/lib.sh

echo_green "Installing GPG and YubiKey tools..."

if [[ $OS == 'darwin' ]]; then
  pkg_install gnupg pinentry-mac

  # YubiKey Manager (CLI)
  if ! (exists ykman); then
    echo_green "Installing ykman (YubiKey Manager)..."
    pkg_install ykman
  else
    echo_cyan "ykman is already installed. Skipping..."
  fi
elif [[ $OS == 'linux' ]]; then
  pkg_install gnupg2 pinentry-curses

  # YubiKey tools for Linux
  pkg_install ykpers yubikey-manager pcsc-lite pcsc-lite-ccid
  sudo systemctl enable pcscd
  sudo systemctl start pcscd
fi

echo_green "Done."

# Ensure GPG configs are in place
echo_green "Setting up GPG configuration..."
mkdir -p "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"

# gpg.conf - symlink to dotfiles version
if [ -L "$HOME/.gnupg/gpg.conf" ] && [ "$(readlink "$HOME/.gnupg/gpg.conf")" = "$HOME/dotfiles/gpg.conf" ]; then
  echo_cyan "gpg.conf already symlinked correctly. Skipping..."
elif [ -f "$HOME/.gnupg/gpg.conf" ]; then
  echo_cyan "gpg.conf already exists - backing up and relinking."
  mv "$HOME/.gnupg/gpg.conf" "$HOME/.gnupg/gpg.conf.old$NOW"
  ln -s "$HOME/dotfiles/gpg.conf" "$HOME/.gnupg/gpg.conf"
else
  ln -s "$HOME/dotfiles/gpg.conf" "$HOME/.gnupg/gpg.conf"
fi

# gpg-agent.conf - copy (not symlink) so we can append OS-specific pinentry
if [ -f "$HOME/.gnupg/gpg-agent.conf" ]; then
  echo_cyan "gpg-agent.conf already exists - backing up and replacing."
  mv "$HOME/.gnupg/gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf.old$NOW"
fi
cp "$HOME/dotfiles/gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf"
if [[ $OS == 'darwin' ]] && command -v pinentry-mac >/dev/null 2>&1; then
  echo "pinentry-program $(which pinentry-mac)" >> "$HOME/.gnupg/gpg-agent.conf"
fi

echo_green "GPG configuration installed."

# Restart the agent to pick up new config
echo_green "Restarting gpg-agent..."
gpgconf --kill gpg-agent 2>/dev/null || true
gpg-connect-agent /bye 2>/dev/null || true
echo_green "Done."
