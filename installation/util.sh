#!/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
set -e


# basic stuff
echo_green "Installing basic utilities..."
pkg_install vim git wget curl zsh tmux tmate jq hub neovim python3-neovim telnet
echo_green "Done."

#hub
echo_green "Installing hub..."
pkg_install hub
echo_green "Done."

#gpg
echo_green "Installing gpg stuffs..."
pkg_install gnupg gpg-agent pinentry-mac
echo_green "Done."
