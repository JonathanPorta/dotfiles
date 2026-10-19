#!/usr/bin/env zsh

set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
# set -e


# basic stuff
echo_green "Installing basic utilities..."
if [[ $OS == 'linux' ]]; then
  echo_green "Removing vim-minimal for Fedora..."
  sudo dnf remove -y vim-minimal
  echo_green "Done."
fi
pkg_install vim
pkg_install git wget curl zsh tmux tmate jq hub neovim telnet
if [[ $OS == 'linux' ]]; then
  pkg_install util-linux-user
fi
echo_green "Done."

#hub
# echo_green "Installing hub..."
# pkg_install hub
# echo_green "Done."

# gh cli
if [[ $OS == 'linux' ]]; then
  echo_green "Installing gh cli for fedora..."
  # Download and validate before touching the installed repo. Keep the signing
  # key refresh and the common dnf4/dnf5 install path.
  if (
    gh_repo_download=$(mktemp) || exit 1
    gh_repo_stage=""
    trap 'rm -f "$gh_repo_download"; if [[ -n "$gh_repo_stage" ]]; then sudo rm -f "$gh_repo_stage"; fi' EXIT

    curl -fsSL --output "$gh_repo_download" https://cli.github.com/packages/rpm/gh-cli.repo || exit 1
    # Require a complete gh-cli definition, including signature verification.
    # Accept rotated key filenames without pinning the current signing key.
    awk '
      { sub(/\r$/, ""); sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, "") }
      /^($|[#;])/ { next }
      /^\[/ {
        if ($0 != "[gh-cli]" || section) invalid = 1
        section = 1
        next
      }
      {
        separator = index($0, "=")
        key = substr($0, 1, separator - 1)
        value = substr($0, separator + 1)
        sub(/[[:space:]]+$/, "", key)
        sub(/^[[:space:]]+/, "", value)
        if (!section || !separator || key !~ /^[a-z][a-z0-9_]*$/ || key in config) invalid = 1
        config[key] = value
      }
      END {
        exit (invalid || !section || config["name"] == "" ||
          config["baseurl"] !~ /^https:\/\/cli\.github\.com\/packages\/rpm\/?$/ ||
          config["enabled"] != "1" || config["gpgcheck"] != "1" ||
          config["gpgkey"] !~ /^https:\/\/cli\.github\.com\/packages\/[^[:space:]]+\.(asc|gpg)$/)
      }
    ' "$gh_repo_download" || exit 1

    # Stage on the destination filesystem so a failed copy cannot damage the
    # working repo, and the final rename replaces it atomically.
    gh_repo_stage=$(sudo mktemp /etc/yum.repos.d/.gh-cli.repo.XXXXXX) || exit 1
    sudo install -m 0644 "$gh_repo_download" "$gh_repo_stage" || exit 1
    sudo mv -f "$gh_repo_stage" /etc/yum.repos.d/gh-cli.repo
  ); then
    if pkg_install gh --repo gh-cli; then
      echo_green "Done."
    else
      echo_red "gh installation failed; repository refresh succeeded." >&2
    fi
  else
    echo_cyan "Skipping gh repository refresh and installation: refresh failed; existing repository configuration was left unchanged." >&2
  fi
elif [[ $OS == 'darwin' ]]; then
  echo_green "Installing gh cli for darwin..."
  pkg_install gh
  echo_green "Done."
fi

# gh cli extensions (these need a logged-in gh)
if (exists gh) && gh auth status >/dev/null 2>&1; then
  gh extension list | grep -q vilmibm/gh-screensaver || gh extension install vilmibm/gh-screensaver
else
  echo_cyan "Skipping gh extensions: run 'gh auth login', then re-run this script."
fi

# GPG is now installed via $INSTALLATION_SOURCE_DIR/gpg.sh

# git-lfs - https://git-lfs.github.com (Fedora and Homebrew both package it)
if ! git lfs version >/dev/null 2>&1; then
  echo_green "Installing git-lfs..."
  pkg_install git-lfs
  git lfs install
  echo_green "Done."
else
  echo_cyan "git-lfs is already installed. Skipping..."
fi
