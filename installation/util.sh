#!/usr/bin/env zsh

set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
# set -e


# basic stuff
echo_green "Installing basic utilities..."
if [[ $OS == 'linux' ]]; then
  echo_green "Removing vim-minimal for Fedora..."
  sudo dnf remove -y vim-minimal
  echo_green "Done."
fi
pkg_install vim
pkg_install git wget curl zsh tmux tmate jq hub neovim telnet
if [[ $OS == 'linux' ]]; then
  pkg_install util-linux-user
fi
echo_green "Done."

#hub
# echo_green "Installing hub..."
# pkg_install hub
# echo_green "Done."

# gh cli
if [[ $OS == 'linux' ]]; then
  echo_green "Installing gh cli for fedora..."
  # Fetch the repo file directly so this works with both dnf4 and dnf5, and so
  # each run picks up GitHub's current signing-key URL.
  curl -fsSL https://cli.github.com/packages/rpm/gh-cli.repo | sudo tee /etc/yum.repos.d/gh-cli.repo > /dev/null
  pkg_install gh --repo gh-cli
  echo_green "Done."
elif [[ $OS == 'darwin' ]]; then
  echo_green "Installing gh cli for darwin..."
  pkg_install gh
  echo_green "Done."
fi

# gh cli extensions (these need a logged-in gh)
if (exists gh) && gh auth status >/dev/null 2>&1; then
  gh extension list | grep -q vilmibm/gh-screensaver || gh extension install vilmibm/gh-screensaver
else
  echo_cyan "Skipping gh extensions: run 'gh auth login', then re-run this script."
fi

# GPG is now installed via $INSTALLATION_SOURCE_DIR/gpg.sh

# git-lfs - https://git-lfs.github.com (Fedora and Homebrew both package it)
if ! git lfs version >/dev/null 2>&1; then
  echo_green "Installing git-lfs..."
  pkg_install git-lfs
  git lfs install
  echo_green "Done."
else
  echo_cyan "git-lfs is already installed. Skipping..."
fi
