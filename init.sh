#!/bin/bash
set -eo pipefail

usage() {
  cat <<HELP
Usage:
  $(basename "$0") [-h|--help] [--headless]

Bootstraps the dotfiles repository: clones (or fetches) the repo, creates
symlinks, installs jq, syncs GitHub authorized_keys, and prepares the shell.

Options:
  -h, --help    Show this help text.
  --headless    Skip interactive confirmation prompts (use detected defaults).

Environment:
  HEADLESS      Set to "true" to skip prompts (same as --headless).
  USER          Override the local username detection.
  HOME          Override the home directory detection.
  GH_USERNAME   Override the GitHub username (default: JonathanPorta).
HELP
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --headless) HEADLESS=true ;;
  esac
done

# Use dynamic username and home directory depending on the OS and available environment variables
if [[ -z "${USER}" ]]; then
    LOCAL_USERNAME=portaj
else
    LOCAL_USERNAME=${USER}
fi

if [[ -z "${HOME}" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        HOME_DIR=/Users/${LOCAL_USERNAME}
    else
        HOME_DIR=/home/${LOCAL_USERNAME}
    fi
else
    HOME_DIR=${HOME}
fi

GH_USERNAME=${GH_USERNAME:-JonathanPorta}
SSH_DIR=${HOME_DIR}/.ssh

# Bootstrap vars (before installation/include/vars.sh is available)
export DEVEL="$HOME_DIR/devel/$LOCAL_USERNAME"
export DOTFILES_CHECKOUT="$DEVEL/dotfiles"
export NOW=$(date -u +%s)

echo "Setting up this machine using:"
echo "  Local Username: ${LOCAL_USERNAME}"
echo "  Github Username: ${GH_USERNAME}"
echo "  Home Directory: ${HOME_DIR}"
echo "  SSH Directory: ${SSH_DIR}"
echo "  Devel Directory: ${DEVEL}"
echo "  Dotfiles Checkout: ${DOTFILES_CHECKOUT}"

if [[ "${HEADLESS}" != "true" ]]; then
  echo ""
  read -r -p "Do these values look correct? [Y/n]: " confirm
  case "${confirm}" in
    [nN]|[nN][oO])
      echo "Aborting. Set USER, HOME, or GH_USERNAME environment variables to override, then re-run."
      exit 1
      ;;
  esac
fi

# Make my typical home dirs
mkdir -p $DEVEL
mkdir -p $HOME_DIR/bin

# Ensure git is installed (fresh machines may not have it)
if ! command -v git >/dev/null 2>&1; then
    echo "Installing git..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Xcode Command Line Tools are required. Installing..."
        xcode-select --install 2>/dev/null || true
        echo "Please complete the Xcode CLI Tools installation dialog, then re-run this script."
        exit 1
    else
        sudo dnf install -y git
    fi
fi

echo "Ensuring a local checkout of github.com/${GH_USERNAME}/dotfiles exists and is where we expect it..."
# if we already have the dotfiles repo cloned then lets fetch and nothing else. yolo
if [ -d "$DOTFILES_CHECKOUT" ]; then
  cd $DOTFILES_CHECKOUT
  git fetch
# if we don't have the repo, let's clone it
else
  git clone https://github.com/${GH_USERNAME}/dotfiles.git $DOTFILES_CHECKOUT
fi

echo "Ensure symlink of '$HOME_DIR/dotfiles' points to '$DOTFILES_CHECKOUT/dotfiles'..."
if [ -L "$HOME_DIR/dotfiles" ] && [ "$(readlink "$HOME_DIR/dotfiles")" = "$DOTFILES_CHECKOUT/dotfiles" ]; then
  echo "'$HOME_DIR/dotfiles' already points to '$DOTFILES_CHECKOUT/dotfiles' - nothing to do."
elif [ -e "$HOME_DIR/dotfiles" ] || [ -L "$HOME_DIR/dotfiles" ]; then
  echo "WARNING: '$HOME_DIR/dotfiles' exists but does not point to '$DOTFILES_CHECKOUT/dotfiles' - relinking."
  mv "$HOME_DIR/dotfiles" "$HOME_DIR/dotfiles.old$NOW"
  ln -s "$DOTFILES_CHECKOUT/dotfiles" "$HOME_DIR/dotfiles"
else
  ln -s "$DOTFILES_CHECKOUT/dotfiles" "$HOME_DIR/dotfiles"
fi

$DOTFILES_CHECKOUT/installation/symlink.sh

# Ensure jq is installed for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Ensure brew is discoverable in non-login shells
        if ! command -v brew >/dev/null 2>&1; then
            for _brew_dir in /opt/homebrew/bin /usr/local/bin; do
                if [[ -x "$_brew_dir/brew" ]]; then
                    export PATH="$_brew_dir:$PATH"
                    break
                fi
            done
        fi
        if command -v brew >/dev/null 2>&1; then
            brew install jq
        else
            echo "Error: Homebrew is not installed. Install it from https://brew.sh/ and re-run this script."
            exit 1
        fi
    else
        sudo dnf install -y jq
    fi
fi

# Python is installed by run.sh on a fresh machine. If it is already available,
# install agent status config now; otherwise run.sh performs this step later.
if command -v python3 >/dev/null 2>&1; then
    "$DOTFILES_CHECKOUT/installation/agent-config.sh"
else
    echo "Deferring Claude/Codex status-line config until run.sh installs Python."
fi

echo "Ensure authorized keys are synced to local authorized_keys..."
mkdir -p $SSH_DIR
# we want to be able to run this and update the authorized keys with whatever we have on GH
FETCHED_KEYS=$(curl -fsSL "https://api.github.com/users/${GH_USERNAME}/keys" | jq -r '.[] | select(.key != null and .key != "") | .key')
if [[ -z "$FETCHED_KEYS" ]]; then
  echo "Error: No valid SSH keys found for GitHub user '${GH_USERNAME}'. authorized_keys not written."
  exit 1
fi
echo "$FETCHED_KEYS" > $SSH_DIR/authorized_keys
echo "Updated '$SSH_DIR/authorized_keys' to:"
cat $SSH_DIR/authorized_keys
echo "Truncated and wrote $(cat $SSH_DIR/authorized_keys | wc -l) keys to '$SSH_DIR/authorized_keys'."
echo "Done."

## DO THIS AGAIN BECAUSE oh-my-zsh moves it.
# Replace existing .zshrc in $HOME with a link to our dotfile version
if [ -f "$HOME_DIR/.zshrc" ]; then
  echo "'$HOME_DIR/.zshrc' already exists - renaming to '$HOME_DIR/.zshrc.old$NOW' and linking to '$HOME_DIR/dotfiles/.zshrc'."
  mv "$HOME_DIR/.zshrc" "$HOME_DIR/.zshrc.old$NOW"
fi
ln -s "$HOME_DIR/dotfiles/.zshrc" "$HOME_DIR/.zshrc"

# Ensure zsh is installed (run.sh requires it)
if ! command -v zsh >/dev/null 2>&1; then
    echo "Installing zsh..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "zsh should be pre-installed on macOS. Something is wrong."
        exit 1
    else
        sudo dnf install -y zsh
    fi
fi

echo "*******************************************"
echo "Initial setup complete!"
echo "To continue setup, restart your shell and please run:"
echo "-------------------------------------------"
echo "zsh -lc \"$DOTFILES_CHECKOUT/run.sh\""
echo "-------------------------------------------"

# $DOTFILES_CHECKOUT/run.sh
