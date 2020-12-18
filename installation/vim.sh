#!/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
set -e


# vim plugins and plugin manager
# TODO: Update vim plugin list
if [ -d "$HOME/.vim/bundle/Vundle.vim" ]; then
  echo_cyan "'$HOME/.vim/bundle/Vundle.vim' already exists - ignoring..."
else
  echo_green "Installing vim plugins..."
  git clone https://github.com/VundleVim/Vundle.vim.git $HOME/.vim/bundle/Vundle.vim
  # possible config to make my own: https://github.com/ddellaquila/dd-vim/blob/master/init.vim
  # curl -fLo $HOME/.vim/autoload/plug.vim --create-dirs \
  # https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  echo_green "Done."
fi
