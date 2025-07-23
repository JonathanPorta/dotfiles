#!/usr/bin/env zsh

set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
set -e


# Python3 and dev deps
echo_green "Installing python3 requirements..."
if [[ $OS == 'linux' ]]; then
    pkg_install python3-devel
  elif [[ $OS == 'darwin' ]]; then
    pkg_install python-build
  fi
echo_green "Done."

if ! (exists virtualenv); then
  echo_green "Installing virtualenv..."
  pip3 install --user virtualenv
  # pkg_install pyenv-virtualenv
  echo_green "Done."
else
  echo_cyan "virtualenv is already installed. Skipping..."
fi

if ! (exists pipenv); then
  echo_green "Installing pipenv..."
  pip3 install --user pipenv
  echo_green "Done."
else
  echo_cyan "pipenv is already installed. Skipping..."
fi

if ! (exists poetry); then
  echo_green "Installing poetry..."
  pipx install poetry
  echo_green "Done."
else
  echo_cyan "poetry is already installed. Skipping..."
fi



# # conda
# if ! (exists conda); then
#   echo_green "Installing anaconda..."
#   if [[ $OS == 'linux' ]]; then
#     # https://docs.anaconda.com/anaconda/install/linux/
#     pkg_install libXcomposite libXcursor libXi libXtst libXrandr alsa-lib mesa-libEGL libXdamage mesa-libGL libXScrnSaver
#     curl -Lo $INSTALLATION_SOURCE_DIR/anaconda.sh https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh
#     chmod +x $INSTALLATION_SOURCE_DIR/anaconda.sh
#     $INSTALLATION_SOURCE_DIR/anaconda.sh && rm $INSTALLATION_SOURCE_DIR/anaconda.sh
#   elif [[ $OS == 'darwin' ]]; then
#     # https://docs.anaconda.com/anaconda/install/mac-os/
#     curl -Lo Anaconda3-2020.11-MacOSX-x86_64.sh https://repo.anaconda.com/archive/Anaconda3-2020.11-MacOSX-x86_64.sh
#     chmod +x ./Anaconda3-2020.11-MacOSX-x86_64.sh
#     ./Anaconda3-2020.11-MacOSX-x86_64.sh
#   fi
#   echo_green "Done."
# else
#   echo_cyan "anaconda is already installed. Skipping..."
# fi
