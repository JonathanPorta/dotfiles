#!/usr/bin/zsh
set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
set -e


# chruby
set +e
source $HOME/.zshrc
set -e
if ! (exists chruby); then
  echo_green "Installing chruby..."
  curl -Lo $INSTALLATION_SOURCE_DIR/chruby-0.3.9.tar.gz "https://github.com/postmodern/chruby/archive/v0.3.9.tar.gz"
  tar -xzvf $INSTALLATION_SOURCE_DIR/chruby-0.3.9.tar.gz -C $INSTALLATION_SOURCE_DIR/
  cd $INSTALLATION_SOURCE_DIR/chruby-0.3.9/
  sudo make install && cd - && rm $INSTALLATION_SOURCE_DIR/chruby-0.3.9.tar.gz && rm -rf $INSTALLATION_SOURCE_DIR/chruby-0.3.9
  echo_green "Done."
else
  echo_cyan "chruby is already installed. Skipping..."
fi

# ruby-install
set +e
source $HOME/.zshrc
set -e
if ! (exists ruby-install); then
  echo_green "Installing ruby-install..."
  curl -Lo $INSTALLATION_SOURCE_DIR/ruby-install-0.7.0.tar.gz "https://github.com/postmodern/ruby-install/archive/v0.7.0.tar.gz"
  tar -xzvf $INSTALLATION_SOURCE_DIR/ruby-install-0.7.0.tar.gz -C $INSTALLATION_SOURCE_DIR/
  cd $INSTALLATION_SOURCE_DIR/ruby-install-0.7.0/
  sudo make install && cd - && rm $INSTALLATION_SOURCE_DIR/ruby-install-0.7.0.tar.gz && rm -rf $INSTALLATION_SOURCE_DIR/ruby-install-0.7.0
  echo_green "Done."
else
  echo_cyan "ruby-install is already installed. Skipping..."
fi

# ruby
set +e
source $HOME/.zshrc
set -e
echo_green "Installing latest ruby..."
ruby-install > /dev/null && ruby-install --latest && ruby-install ruby --no-reinstall
echo_cyan "You may need to bump the default ruby version as selected in .zshrc"
