#!/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
# set -e


# basic stuff
echo_green "Installing basic utilities..."
# TODO: Update for multi-os
sudo dnf remove -y vim-minimal
pkg_install vim
pkg_install git wget curl zsh tmux tmate jq hub neovim python3-neovim telnet util-linux-user
echo_green "Done."

#hub
echo_green "Installing hub..."
pkg_install hub
echo_green "Done."

#gpg
echo_green "Installing gpg stuffs..."
pkg_install gnupg gpg-agent pinentry-mac
echo_green "Done."

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
