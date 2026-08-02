#!/usr/bin/env zsh
set -e

source $(cd $(dirname "$0") && pwd)/installation/include/lib.sh
is_installed jq
is_installed curl

$DOTFILES_CHECKOUT/installation/symlink.sh

echo_green "Installing applications..."
echo_cyan "About to run '$DOTFILES_CHECKOUT/installation/all.sh'."
$DOTFILES_CHECKOUT/installation/all.sh

echo_cyan "Installing Claude and Codex status-line configuration..."
$DOTFILES_CHECKOUT/installation/agent-config.sh

echo "*******************************************"
echo "Intial setup complete!"
echo "To finish setup, restart your shell."
echo "*******************************************"
