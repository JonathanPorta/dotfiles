#!/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
set -e


# Python3.8 and dev deps
echo_green "Installing python3 requirements..."
pkg_install python3.8 python3-devel python3-pip pipenv
echo_green "Done."

if ! (exists virtualenv); then
  echo_green "Installing virtualenv..."
  pip3 install --user virtualenv
  echo_green "Done."
else
  echo_cyan "virtualenv is already installed. Skipping..."
fi

# conda
if ! (exists conda); then
  echo_green "Installing anaconda..."
  if [[ $OS == 'linux' ]]; then
    # https://docs.anaconda.com/anaconda/install/linux/
    pkg_install libXcomposite libXcursor libXi libXtst libXrandr alsa-lib mesa-libEGL libXdamage mesa-libGL libXScrnSaver
    curl -Lo $INSTALLATION_SOURCE_DIR/anaconda.sh https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh
    chmod +x $INSTALLATION_SOURCE_DIR/anaconda.sh
    $INSTALLATION_SOURCE_DIR/anaconda.sh && rm $INSTALLATION_SOURCE_DIR/anaconda.sh
  elif [[ $OS == 'darwin' ]]; then
    # https://docs.anaconda.com/anaconda/install/mac-os/
    curl -Lo Anaconda3-2020.11-MacOSX-x86_64.sh https://repo.anaconda.com/archive/Anaconda3-2020.11-MacOSX-x86_64.sh
    chmod +x ./Anaconda3-2020.11-MacOSX-x86_64.sh
    ./Anaconda3-2020.11-MacOSX-x86_64.sh
  fi
  echo_green "Done."
else
  echo_cyan "anaconda is already installed. Skipping..."
fi
