#!/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALL_DIR/include/lib.sh
set -e

if ! (exists chruby); then
  wget -O $INSTALL_DIR/chruby-0.3.9.tar.gz https://github.com/postmodern/chruby/archive/v0.3.9.tar.gz
  tar -xzvf $INSTALL_DIR/chruby-0.3.9.tar.gz
  cd $INSTALL_DIR/chruby-0.3.9/
  sudo make install && cd - && rm $INSTALL_DIR/chruby-0.3.9.tar.gz && rm -rf $INSTALL_DIR/chruby-0.3.9
fi

# ruby-install
if ! (exists ruby-install); then
  wget -O $INSTALL_DIR/ruby-install-0.7.0.tar.gz https://github.com/postmodern/ruby-install/archive/v0.7.0.tar.gz
  tar -xzvf $INSTALL_DIR/ruby-install-0.7.0.tar.gz
  cd $INSTALL_DIR/ruby-install-0.7.0/
  sudo make install && cd - && rm $INSTALL_DIR/ruby-install-0.7.0.tar.gz && rm -rf $INSTALL_DIR/ruby-install-0.7.0
fi
set +e
source $HOME/.zshrc
set -e
# ruby
ruby-install && ruby-install ruby --no-reinstall
echo "You may need to bump the default ruby version as selected in .zshrc"
