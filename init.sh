#!/bin/bash
set -e

# Copy of source $HOME/devel/portaj/dotfiles/installation/lib/vars.sh in case it doesn't exist yet!
export DEVEL="$HOME/devel/portaj"
export DOTFILES_CHECKOUT="$DEVEL/dotfiles"
export NOW=$(date -u +%s)

# Make my typical home dirs
mkdir -p $DEVEL
mkdir -p $HOME/bin

echo "Ensuring a local checkout of github.com/jonathanporta/dotfiles exists and is where we expect it..."
# if we already have the dotfiles repo cloned then lets fetch and nothing else. yolo
if [ -d "$DOTFILES_CHECKOUT" ]; then
  cd $DOTFILES_CHECKOUT
  git fetch
# if we don't have the repo, let's clone it
else
  git clone git@github.com:JonathanPorta/dotfiles.git $DOTFILES_CHECKOUT
fi

echo "Ensure symlink of '$HOME/dotfiles' points to '$DOTFILES_CHECKOUT/dotfiles $HOME/dotfiles'..."
# if there is no dotfiles directory under $HOME - link to the dotfiles subfolder in our repo
if [ ! -d "$HOME/dotfiles" ]; then
  ln -s $DOTFILES_CHECKOUT/dotfiles $HOME/dotfiles
fi

$DOTFILES_CHECKOUT/installation/symlink.sh

echo "Ensure authorized keys are synced to local authorized_keys..."
# we want to be able to run this and update the authorized keys with whatever we have on GH
curl https://api.github.com/users/jonathanporta/keys | jq -r '.[] | .key' > $HOME/.ssh/authorized_keys
echo "Updated '$HOME/.ssh/authorized_keys' to:"
cat $HOME/.ssh/authorized_keys
echo "Truncated and wrote $(cat $HOME/.ssh/authorized_keys | wc -l) keys to '$HOME/.ssh/authorized_keys'."
echo "Done."

echo "Installing oh-my-zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
export ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
$DOTFILES_CHECKOUT/installation/oh-my-zsh.sh
echo "Done."

## DO THIS AGAIN BECAUSE oh-my-zsh moves it.
# Replace existing .zshrc in $HOME with a link to our dotfile version
if [ -f "$HOME/.zshrc" ]; then
  echo "'$HOME/.zshrc' already exists - renaming to '$HOME/.zshrc.old$NOW' and linking to '$HOME/dotfiles/.zshrc'."
  mv "$HOME/.zshrc" "$HOME/.zshrc.old$NOW"
fi
ln -s "$HOME/dotfiles/.zshrc" "$HOME/.zshrc"

echo "*******************************************"
echo "Intial setup complete!"
echo "To continue setup, restart your shell and please run:"
echo "-------------------------------------------"
echo "source $HOME/.zshrc && $DOTFILES_CHECKOUT/run.sh"
echo "-------------------------------------------"

# $DOTFILES_CHECKOUT/run.sh
