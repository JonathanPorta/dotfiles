#!/usr/bin/zsh
set -e

source $(cd $(dirname "$0") && pwd)/installation/include/lib.sh
is_installed jq
is_installed curl

set +e
source $HOME/.zshrc
set -e
$DOTFILES_CHECKOUT/installation/symlink.sh
set +e
source $HOME/.zshrc
set -e

echo_green "Installing applications..."
echo_cyan "About to run '$DOTFILES_CHECKOUT/installation/all.sh'."
$DOTFILES_CHECKOUT/installation/all.sh

echo "*******************************************"
echo "Intial setup complete!"
echo "To finish setup, restart your shell."
echo "*******************************************"
