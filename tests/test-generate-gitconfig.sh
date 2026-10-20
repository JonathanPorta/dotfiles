#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
generator="$repo_root/dotfiles/helpers/generate_gitconfig.sh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# zsh: sourcing the generator (as .profile does) must not change directory, so
# chpwd hooks such as spaceship's never run during shell startup.
mkdir -p "$test_root/zsh-home"
HOME="$test_root/zsh-home" zsh -f -c '
  marker=$HOME/chpwd-ran
  chpwd() { print -r -- "$PWD" >>$marker }
  source "$1" >/dev/null
  [[ ! -e $marker ]] || { print -u2 "chpwd ran: $(<$marker)"; exit 1 }
' zsh "$generator" || fail "sourcing from zsh ran a chpwd hook"
grep -qF "generated via $generator." "$test_root/zsh-home/.gitconfig" ||
  fail "zsh: .gitconfig does not name the generator path"

# bash: running it directly still records the generator's absolute path.
mkdir -p "$test_root/bash-home"
HOME="$test_root/bash-home" bash "$generator" >/dev/null
grep -qF "generated via $generator." "$test_root/bash-home/.gitconfig" ||
  fail "bash: .gitconfig does not name the generator path"

# A relative invocation is resolved against the current directory.
mkdir -p "$test_root/rel-home"
(cd "$(dirname "$generator")" && HOME="$test_root/rel-home" bash ./generate_gitconfig.sh >/dev/null)
grep -qF "generated via $generator." "$test_root/rel-home/.gitconfig" ||
  fail "relative: .gitconfig does not name the generator path"

echo "PASS: generate_gitconfig.sh"
