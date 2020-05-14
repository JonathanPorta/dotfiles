#!/bin/bash
set -e

sudo dnf clean all ; sudo dnf makecache
INSTALL_DIR=$(dirname "$0")
source $INSTALL_DIR/include/lib.sh

cd $INSTALL_DIR
$INSTALL_DIR/util.sh
$INSTALL_DIR/oh-my-zsh.sh
$INSTALL_DIR/rpm-fusion.sh
$INSTALL_DIR/fedora.sh
$INSTALL_DIR/ruby.sh
$INSTALL_DIR/python3.sh
$INSTALL_DIR/node.sh
$INSTALL_DIR/vim.sh
cd -
