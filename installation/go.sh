#!/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALL_DIR/include/lib.sh
set -e


# go
if ! (exists go); then
  if [[ $OS == 'linux' ]]; then
    echo_green "Installing go..."
    pkg_install golang
    echo_green "Done."
  else
    echo_green "Installing go1.15.6.darwin-amd64.pkg from golang.org..."
    install_dmg "https://golang.org/dl/go1.15.6.darwin-amd64.pkg"
    echo_green "Done."
  fi
else
  echo_cyan "go is already installed. Skipping."
fi
