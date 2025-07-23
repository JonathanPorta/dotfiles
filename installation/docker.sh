#!/usr/bin/env zsh

set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
# set -e


# docker
if ! (exists docker); then
  #TODO: Make this handle dnf remove stuff similar to pkg_install
  if [[ $OS == 'linux' ]]; then
    echo_green "Installing docker..."
    echo_cyan "Removing old docker installs first..."
    sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine
    echo_cyan "Adding official Docker repos..."
    pkg_install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    echo_green "Installing Docker..."
    pkg_install docker-ce docker-ce-cli containerd.io
    echo_green "Done."
  elif [[ $OS == 'darwin' ]]; then
    echo_green "Installing Docker.dmg from desktop.docker.com..."
    install_dmg https://desktop.docker.com/mac/stable/Docker.dmg
    echo_green "Running Docker app to continue installation..."
    open /Applications/Docker.app
    echo_green "Done."
  fi
else
  echo_cyan "docker is already installed. Skipping..."
fi
