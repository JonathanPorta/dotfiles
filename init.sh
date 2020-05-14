#!/bin/bash
set -e
# Make my typical devel directory
export DEVEL="$HOME/devel/portaj"
export DOTFILES_CHECKOUT="$DEVEL/dotfiles"
mkdir -p $DEVEL

# if we already have the dotfiles repo cloned then lets fetch and nothing else. yolo
if [ -d "$DOTFILES_CHECKOUT" ]; then
  cd $DOTFILES_CHECKOUT
  git fetch
# if we don't have the repo, let's clone it
else
  git clone git@github.com:JonathanPorta/dotfiles.git $DOTFILES_CHECKOUT
fi

# if there is no dotfiles directory under $HOME - link to the dotfiles subfolder in our repo
if [ ! -d "$HOME/dotfiles" ]; then
  ln -s $DOTFILES_CHECKOUT/dotfiles $HOME/dotfiles
fi

echo "About to run '$DOTFILES_CHECKOUT/run.sh'."
$DOTFILES_CHECKOUT/run.sh
