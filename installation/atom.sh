#!/usr/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
# set -e


#atom editor
if ! (exists atom); then
  if [[ $OS == 'linux' ]]; then
    echo_green "Installing atom..."
    #TODO: Add nvidia stuff here or in a separate file... maybe?
    curl -Lo atom.rpm "https://atom.io/download/rpm"
    pkg_install ./atom.rpm && rm ./atom.rpm
    echo_green "Done."
  else
    echo_green "Installing Docker.dmg from desktop.docker.com..."
    install_dmg "https://atom.io/download/mac"
    echo_cyan "Linking /Applications/Atom.app/Contents/Resources/app/atom.sh to /usr/local/bin/atom..."
    ln -s /Applications/Atom.app/Contents/Resources/app/atom.sh /usr/local/bin/atom
    echo_green "Done."
  fi
else
  echo_cyan "atom is already installed. Skipping..."
fi
