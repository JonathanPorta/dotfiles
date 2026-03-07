# https://unix.stackexchange.com/a/71258/103099
# https://stackoverflow.com/a/18187389

# Homebrew shell environment - runs once on login (not every interactive shell)
if [[ "$(uname)" == "Darwin" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
