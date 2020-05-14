#!/bin/bash
set -e

echo "Install vim customizations"
git clone https://github.com/VundleVim/Vundle.vim.git $HOME/.vim/bundle/Vundle.vim
# possible config to make my own: https://github.com/ddellaquila/dd-vim/blob/master/init.vim
# curl -fLo $HOME/.vim/autoload/plug.vim --create-dirs \
    # https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
#
