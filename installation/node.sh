#!/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALL_DIR/include/lib.sh
set -e

if ! (exists nvm); then
  NVM_DIR="$HOME/.nvm" && (
    git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
    cd "$NVM_DIR"
    git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
  ) && \. "$NVM_DIR/nvm.sh"
  source $HOME/.zshrc
else
  echo "nvm is already installed...skipping"
fi

if ! (exists node); then
  echo "Installing latest version of Node.js:"
  nvm install node
else
  NODE_VERSION=$(node --version)
  echo "$NODE_VERSION is already installed...skipping"
fi

if [ -d "$HOME/.nenv" ]; then
  echo "'$HOME/.nenv' already exists...skipping"
else
  echo "installing nenv..."
  git clone https://github.com/ryuone/nenv.git $HOME/.nenv  
fi
