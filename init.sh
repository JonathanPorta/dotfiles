#!/bin/bash

# Make my typical devel directory
DEVEL="$HOME/devel/portaj"
mkdir -p $DEVEL

# if we already have the dotfiles repo cloned then lets fetch and nothing else. yolo
if [ -d "$DEVEL/dotfiles" ]; then
  cd $DEVEL/dotfiles
  git fetch
# if we don't have the repo, let's clone it
else
  cd $DEVEL
  git clone git@github.com:JonathanPorta/dotfiles.git
fi

# if there is no dotfiles directory under $HOME - link to the dotfiles subfolder in our repo
if [ ! -d "$HOME/dotfiles" ]; then
  ln -s $DEVEL/dotfiles/dotfiles $HOME/dotfiles
fi
