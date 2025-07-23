#!/usr/bin/env zsh

set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
# set -e

# nvm
if ! (exists nvm); then
  echo_green "Installing latest node.js..."
  NVM_DIR="$HOME/.nvm" && (
    git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
    cd "$NVM_DIR"
    git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
  ) && \. "$NVM_DIR/nvm.sh"
  source $HOME/.zshrc
  echo_green "Done."
else
  echo_cyan "nvm is already installed. Skipping..."
fi

# node
if ! (exists node); then
  echo_green "Installing latest node.js..."
  nvm install node
  echo_green "Done."
else
  NODE_VERSION=$(node --version)
  echo_cyan "$NODE_VERSION is already installed. Skipping..."
fi

# .nenv
if [ -d "$HOME/.nenv" ]; then
  echo_cyan "'$HOME/.nenv' already exists. Skipping..."
else
  echo_green "Installing nenv..."
  git clone https://github.com/ryuone/nenv.git $HOME/.nenv
  echo_green "Done."
fi

# yarn
if ! (exists "yarn"); then
  echo_green "Installing yarn..."
  if [[ $OS == 'linux' ]]; then
    curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | sudo tee /etc/yum.repos.d/yarn.repo
    pkg_install yarn
  elif [[ $OS == 'darwin' ]]; then
    pkg_install yarn
  fi
  echo_green "Done."
else
  echo_cyan "yarn is already installed. Skipping..."
fi
