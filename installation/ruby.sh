#!/bin/bash
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALL_DIR/include/lib.sh
source $HOME/.chruby
set -e

if ! exists chruby; then
  wget -O chruby-0.3.9.tar.gz https://github.com/postmodern/chruby/archive/v0.3.9.tar.gz
  tar -xzvf chruby-0.3.9.tar.gz
  cd chruby-0.3.9/
  sudo make install && cd .. && rm chruby-0.3.9.tar.gz && rm -rf chruby-0.3.9
fi

# ruby-install
if ! exists ruby-install; then
  wget -O ruby-install-0.7.0.tar.gz https://github.com/postmodern/ruby-install/archive/v0.7.0.tar.gz
  tar -xzvf ruby-install-0.7.0.tar.gz
  cd ruby-install-0.7.0/
  sudo make install && cd .. && rm ruby-install-0.7.0.tar.gz && rm -rf ruby-install-0.7.0
fi
set +e
source $HOME/.chruby
set -e
# ruby
if ! exists ruby; then
  ruby-install ruby
  echo "You may need to bump the default ruby version as selected in .zshrc"
fi
