#!/usr/bin/env zsh
set -e

source $(cd $(dirname "$0") && pwd)/installation/include/lib.sh
is_installed jq
is_installed curl

# Warn (never fail) when this Fedora release has stopped getting updates.
if [[ $OS == 'linux' ]] && (exists rpm); then
  fedora_eol=$(curl -fsS --max-time 5 "https://bodhi.fedoraproject.org/releases/F$(rpm -E %fedora)" 2>/dev/null | jq -r '.eol // empty' 2>/dev/null) || true
  if [[ -n "$fedora_eol" && "$fedora_eol" < "$(date +%F)" ]]; then
    echo_red "WARNING: Fedora $(rpm -E %fedora) reached end of life on $fedora_eol and no longer gets updates. Upgrade soon."
  fi
fi

$DOTFILES_CHECKOUT/installation/symlink.sh

echo_green "Installing applications..."
echo_cyan "About to run '$DOTFILES_CHECKOUT/installation/all.sh'."
$DOTFILES_CHECKOUT/installation/all.sh

echo_cyan "Configuring optional Claude and Codex agent settings..."
$DOTFILES_CHECKOUT/installation/agent-config.sh

echo "*******************************************"
echo "Intial setup complete!"
echo "To finish setup, restart your shell."
echo "*******************************************"
