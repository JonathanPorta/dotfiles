#!/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALL_DIR/include/lib.sh
set -e

echo "Installing python3 requirements."
sudo dnf install -y python3 python3-devel python3-pip

if ! (exists virtualenv); then
  echo "Installing virtualenv..."
  pip3 install --user virtualenv
else
  echo "virtualenv is already installed...skipping"
fi


# if ! (exists anaconda); then
#   echo "Installing anaconda....Comment this out if you don't want none, honey."
#   # # https://docs.anaconda.com/anaconda/install/linux/
#   # sudo dnf install -y libXcomposite libXcursor libXi libXtst libXrandr alsa-lib mesa-libEGL libXdamage mesa-libGL libXScrnSaver
#   # curl -Lo anaconda.sh https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh
#   # chmod +x ./anaconda.sh
#   # ./anaconda.sh && rm ./anaconda.sh
# else
  echo "anaconda is already installed...skipping"
# fi
