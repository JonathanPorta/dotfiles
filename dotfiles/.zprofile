# https://unix.stackexchange.com/a/71258/103099
# https://stackoverflow.com/a/18187389

# Homebrew shell environment - runs once on login (not every interactive shell)
if [[ "$(uname)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi
