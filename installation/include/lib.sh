#!/usr/bin/zsh

# Figure out best way to include this in all scripts, even when we don't know the path.
source $(cd $(dirname "$0") && pwd)/vars.sh
# example we can use in other scripts to include this file:
# source $(cd $(dirname "$0") && pwd)/lib.sh

# Common Functions
# usage: exists "command or function name" e.g. exists jq
#        exit $(exists jq) will return 0 exit code if it exists, or something else if it doesn't exist.
#TODO: Improve this to handle functions and such: https://unix.stackexchange.com/questions/89048/how-to-test-if-command-is-alias-function-or-binary
export exists(){
  command -v "$1" >/dev/null 2>&1
}

# usage: pkg_installer pkg - runs pkg installer
export pkg_install(){
  if [[ $OS == 'linux' ]]; then
     sudo dnf install -y "$@"
  elif [[ $OS == 'darwin' ]]; then
     brew install "$@"
  fi
}

# Common Functions

#TODO: Make a version of this that tells you it's not installed but ultimately doesn't exit so that we can use it as debug output where we currently use only exists wrapped in a conditional.
# usage: is_installed cmd [error_message]
#        is_installed will exit non-0 and echo the given error message, if it was specified. Otherwise, it will echo a generic error stating that the command doesn't exist.
export is_installed(){
  if [ -z "$2" ]
  then
    error_message="$1 not found. Please install it and try again."
  else
    error_message="$2"
  fi
  exists $1 || { echo_red "$error_message" >&2; exit 1; }
}

# usage: install_dmg url e.g. install_dmg https://desktop.docker.com/mac/stable/Docker.dmg
#        NOTE: copy-pasta from https://apple.stackexchange.com/a/311511
#        install_dmg url will exit non-0 if anything goes wrong.
function install_dmg {
    set -x
    tempd=$(mktemp -d)
    curl -Lo $tempd/pkg.dmg $1
    listing=$(sudo hdiutil attach $tempd/pkg.dmg | grep Volumes)
    volume=$(echo "$listing" | cut -f 3)
    if [ -e "$volume"/*.app ]; then
      sudo cp -rf "$volume"/*.app /Applications
    elif [ -e "$volume"/*.pkg ]; then
      package=$(ls -1 "$volume" | grep .pkg | head -1)
      sudo installer -pkg "$volume"/"$package" -target /
    fi
    sudo hdiutil detach "$(echo "$listing" | cut -f 1 | sed 's/ *$//')"

    rm -rf $tempd
    set +x
}

# usage: parent_dir "file or script path" e.g. parent_dir $0
#        parent_dir /home/portaj/Downloads/script.sh will return /home/portaj/Downloads
export parent_dir(){
  echo $(cd $(dirname "$1") && pwd)
}


# Output Formatting
export echo_red() {
	printf "\033[0;31m%s\033[0m\n" "$@"
}

export echo_green() {
	printf "\033[0;32m%s\033[0m\n" "$@"
}

export echo_cyan() {
	printf "\033[0;36m%s\033[0m\n" "$@"
}

# # TODO: enable debug output with an arg, for now, uncomment the following:
# echo_cyan "INCLUDE_DIR=$INCLUDE_DIR"
# echo_cyan "INSTALLATION_SOURCE_DIR=$INSTALLATION_SOURCE_DIR"
# echo_cyan "DEVEL_DIR=$DEVEL_DIR"
# echo_cyan "DOTFILES_CHECKOUT=$DOTFILES_CHECKOUT"
# echo_cyan "NOW=$NOW"
# echo_cyan "OS=$OS"
# echo_cyan "PKG_INSTALLER=$PKG_INSTALLER"
