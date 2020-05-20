#!/bin/zsh
source $HOME/.zshrc

export exists(){
  command -v "$1" >/dev/null 2>&1
}
