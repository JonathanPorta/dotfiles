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
  sudo dnf install dnf5-plugins
  sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
  sudo dnf install gh --repo gh-cli
  echo_green "Done."
elif [[ $OS == 'darwin' ]]; then
  echo_green "Installing gh cli for darwin..."
  pkg_install gh
  echo_green "Done."
fi

# gh cli extensions
gh extension install vilmibm/gh-screensaver

# GPG is now installed via $INSTALLATION_SOURCE_DIR/gpg.sh

# git-lfs - https://git-lfs.github.com
# TODO: Have a way to test if a command returns non-0 since this check ensures we always try to install git-lfs
if ! (exists "git lfs install"); then
  echo_green "Installing git-lfs..."
  if [[ $OS == 'linux' ]]; then
    curl -s -o ./gitlfs.sh "https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh"
    chmod +x ./gitlfs.sh
    sudo os=fedora dist=32 ./gitlfs.sh
    pkg_install git-lfs
    git lfs install
    rm ./gitlfs.sh
  elif [[ $OS == 'darwin' ]]; then
    # install_dmg "https://github.com/git-lfs/git-lfs/releases/download/v2.13.1/git-lfs-darwin-amd64-v2.13.1.zip"
    pkg_install git-lfs
  fi
  echo_green "Done."
else
  echo_cyan "git-lfs is already installed. Skipping..."
fi
