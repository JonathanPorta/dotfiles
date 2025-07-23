#!/usr/bin/env zsh

set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
# set -e


echo_green "Installing RPM Fusion Free and Non-Free Repos..."
pkg_install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
echo_green "Done."

echo_green "Installing Fedora utilities..."
pkg_install gnome-tweak-tool dolphin smb4k dnf-plugins-core git-subtree
echo_green "Done."

echo_green "Installing Fedy..."
sudo dnf -y copr enable kwizart/fedy
pkg_install fedy
echo_green "Done."
