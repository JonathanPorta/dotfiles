#!/bin/bash

# Determine the OS type
OS="echo 'Unknown OS...'; exit 1"
UNAME_OUTPUT=`uname`
if [[ "$UNAME_OUTPUT" == 'Linux' ]]; then
   OS='linux'
elif [[ "$UNAME_OUTPUT" == 'Darwin' ]]; then
   OS='darwin'
fi

# Determine which package manager to use.
PKG_INSTALLER="echo 'Unknown Installer...'; exit 1"
if [[ $OS == 'linux' ]]; then
   PKG_INSTALLER="sudo dnf install -y"
elif [[ $OS == 'darwin' ]]; then
   PKG_INSTALLER="$(which brew) install"
fi

# export variables that the other scripts will need
# we do this weird cd stuff in order to solve for weird ways this script might get called.
# there may be a better way to handle this, but, this seems to work for now.
# Respect already-exported values (e.g. from init.sh) to support non-default usernames.
export INCLUDE_DIR=$(cd $(dirname "$0") && pwd)
export INSTALLATION_SOURCE_DIR="$(cd "$INCLUDE_DIR" && cd ../ && pwd)"
export DEVEL_DIR="${DEVEL_DIR:-$HOME/devel/${USER:-portaj}}"
export DOTFILES_CHECKOUT="${DOTFILES_CHECKOUT:-$DEVEL_DIR/dotfiles}"
export NOW=$(date -u +%s)
export PKG_INSTALLER=$PKG_INSTALLER
export OS=$OS

# The output of this file should look something like:
# INCLUDE_DIR=/Users/portaj/devel/portaj/dotfiles/installation/include
# INSTALLATION_SOURCE_DIR=/Users/portaj/devel/portaj/dotfiles/installation
# DEVEL_DIR=/Users/portaj/devel/portaj
# DOTFILES_CHECKOUT=/Users/portaj/devel/portaj/dotfiles
# NOW=1602295068
# OS=darwin
# PKG_INSTALLER=brew install

# TODO: enable debug output with an arg, for now, uncomment the following:
# echo "INCLUDE_DIR=$INCLUDE_DIR"
# echo "INSTALLATION_SOURCE_DIR=$INSTALLATION_SOURCE_DIR"
# echo "DEVEL_DIR=$DEVEL_DIR"
# echo "DOTFILES_CHECKOUT=$DOTFILES_CHECKOUT"
# echo "NOW=$NOW"
# echo "OS=$OS"
# echo "PKG_INSTALLER=$PKG_INSTALLER"
