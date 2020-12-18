#!/bin/zsh
set -e

source $(cd $(dirname "$0") && pwd)/installation/include/lib.sh
is_installed jq
is_installed curl

echo_green "Installing applications..."
echo_cyan "About to run '$DOTFILES_CHECKOUT/installation/all.sh'."
$DOTFILES_CHECKOUT/installation/all.sh
