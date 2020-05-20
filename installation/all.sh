#!/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALL_DIR/include/lib.sh
set -e

$INSTALL_DIR/util.sh
$INSTALL_DIR/oh-my-zsh.sh
$INSTALL_DIR/rpm-fusion.sh
$INSTALL_DIR/fedora.sh
$INSTALL_DIR/ruby.sh
$INSTALL_DIR/python3.sh
$INSTALL_DIR/node.sh
$INSTALL_DIR/vim.sh
