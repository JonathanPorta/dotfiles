#!/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALL_DIR/include/lib.sh
set -e
# echo "Installing Fedy"
# sudo dnf -y copr enable kwizart/fedy
# sudo dnf install -y fedy

echo "Installing Gnome Tweak Tool"
sudo dnf install -y gnome-tweak-tool dolphin smb4k

# echo "Installing Dolphin and smb4k"
# sudo dnf install -y dolphin smb4k
if ! (exists atom); then
  echo "Installing Atom"
  curl -Lo atom.rpm https://atom.io/download/rpm
  sudo dnf install -y ./atom.rpm && rm ./atom.rpm
else
  echo "atom is already installed...skipping"
fi

if ! (exists docker); then
  echo "Installing docker via moby-engine"
  sudo dnf install -y moby-engine
else
  echo "docker is already installed...skipping"
fi
