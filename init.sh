#!/bin/bash
set -e


# Copy of source $HOME/devel/portaj/dotfiles/installation/lib/vars.sh in case it doesn't exist yet!
export DEVEL="$HOME/devel/portaj"
export DOTFILES_CHECKOUT="$DEVEL/dotfiles"
export NOW=$(date -u +%s)

# Make my typical home dirs
mkdir -p $DEVEL
mkdir -p $HOME/bin

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

echo "Ensuring a local checkout of github.com/jonathanporta/dotfiles exists and is where we expect it..."
# if we already have the dotfiles repo cloned then lets fetch and nothing else. yolo
if [ -d "$DOTFILES_CHECKOUT" ]; then
  cd $DOTFILES_CHECKOUT
  git fetch
# if we don't have the repo, let's clone it
else
  git clone https://github.com/JonathanPorta/dotfiles.git $DOTFILES_CHECKOUT
fi

echo "Ensure symlink of '$HOME/dotfiles' points to '$DOTFILES_CHECKOUT/dotfiles $HOME/dotfiles'..."
# if there is no dotfiles directory under $HOME - link to the dotfiles subfolder in our repo
if [ ! -d "$HOME/dotfiles" ]; then
  ln -s $DOTFILES_CHECKOUT/dotfiles $HOME/dotfiles
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

echo "Ensure authorized keys are synced to local authorized_keys..."
mkdir -p $HOME/.ssh
# we want to be able to run this and update the authorized keys with whatever we have on GH
curl https://api.github.com/users/jonathanporta/keys | jq -r '.[] | .key' > $HOME/.ssh/authorized_keys
echo "Updated '$HOME/.ssh/authorized_keys' to:"
cat $HOME/.ssh/authorized_keys
echo "Truncated and wrote $(cat $HOME/.ssh/authorized_keys | wc -l) keys to '$HOME/.ssh/authorized_keys'."
echo "Done."

## DO THIS AGAIN BECAUSE oh-my-zsh moves it.
# Replace existing .zshrc in $HOME with a link to our dotfile version
if [ -f "$HOME/.zshrc" ]; then
  echo "'$HOME/.zshrc' already exists - renaming to '$HOME/.zshrc.old$NOW' and linking to '$HOME/dotfiles/.zshrc'."
  mv "$HOME/.zshrc" "$HOME/.zshrc.old$NOW"
fi
ln -s "$HOME/dotfiles/.zshrc" "$HOME/.zshrc"

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
