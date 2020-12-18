#!/bin/zsh

set +e
source $(cd $(dirname "$0") && pwd)/include/lib.sh
# echo $INSTALLATION_SOURCE_DIR
# set -e

# TODO: Verify that we're in zsh: https://stackoverflow.com/questions/9910966/how-to-get-shell-to-self-detect-using-zsh-or-bash#9911082
echo_cyan "From here on, we expect to be running in ZSH not BASH. If errors happen, verify that this is running in ZSH and not BASH."
$INSTALLATION_SOURCE_DIR/util.sh
$INSTALLATION_SOURCE_DIR/oh-my-zsh.sh
$INSTALLATION_SOURCE_DIR/docker.sh
$INSTALLATION_SOURCE_DIR/vim.sh
$INSTALLATION_SOURCE_DIR/atom.sh

#TODO: Make OS specific utility file or something.
if [[ $OS == 'linux' ]]; then
  $INSTALLATION_SOURCE_DIR/fedora.sh
else
  echo_cyan "Skipping fedora.sh due to OS registering as $OS."
fi

$INSTALLATION_SOURCE_DIR/ruby.sh
$INSTALLATION_SOURCE_DIR/python3.sh
$INSTALLATION_SOURCE_DIR/node.sh
