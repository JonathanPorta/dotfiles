#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
real_git=$(command -v git)
mkdir -p "$test_root/bin" "$test_root/home" "$test_root/tmp"
git config --file "$test_root/gitconfig" url.https://work.ghe.com/.insteadOf https://github.com/

# Run the real utility installer, including its shared library. No package
# installation or network calls are allowed in this fixture.
cat >"$test_root/util.zsh" <<'ZSH'
uname() { print Darwin; }
brew() {
  if [[ "$1" == list ]]; then print "$4 1.0"; else print 'unexpected brew install' >>"$TEST_LOG"; return 99; fi
}
git() {
  if [[ "$1" == lfs ]]; then return 0; else "$REAL_GIT" "$@"; fi
}
gh() {
  print -r -- "$GH_HOST|${GH_REPO-unset}|$*" >>"$TEST_LOG"
  [[ "$GH_HOST" == github.com && -z "${GH_REPO:-}" ]] || return 98
  case "$*" in
    'auth status --hostname github.com') [[ "$TEST_MODE" != unauthenticated ]];;
    'extension list') [[ "$TEST_MODE" != installed ]] || print 'vilmibm/gh-screensaver'; return 0;;
    'extension install https://github.com/vilmibm/gh-screensaver')
      [[ "$(git ls-remote --get-url "$3")" == "$3" ]];;
    *) return 97;;
  esac
}
source "$INSTALLATION_SOURCE_DIR/util.sh"
ZSH
for mode in missing installed unauthenticated; do
  : >"$test_root/calls"
  env -i PATH="$PATH" HOME="$test_root/home" TMPDIR="$test_root/tmp" \
    GIT_CONFIG_GLOBAL="$test_root/gitconfig" GIT_CONFIG_NOSYSTEM=1 \
    GH_HOST=work.ghe.com GH_REPO=work.ghe.com/org/work REAL_GIT="$real_git" \
    INSTALLATION_SOURCE_DIR="$repo_root/installation" TEST_LOG="$test_root/calls" \
    TEST_MODE="$mode" zsh "$test_root/util.zsh" >"$test_root/output" 2>&1
  grep -Fx 'github.com|unset|auth status --hostname github.com' "$test_root/calls" >/dev/null
  case "$mode" in
    missing) grep -Fx 'github.com|unset|extension install https://github.com/vilmibm/gh-screensaver' "$test_root/calls" >/dev/null;;
    installed|unauthenticated) if grep 'extension install' "$test_root/calls"; then exit 1; fi;;
  esac
  if [[ "$mode" == unauthenticated ]]; then
    grep 'gh auth login --hostname github.com' "$test_root/output" >/dev/null
  fi
  if grep -E 'unexpected|work.ghe.com' "$test_root/calls"; then exit 1; fi
  echo "PASS: screensaver $mode"
done

# Stop bootstrap immediately after recording clone/fetch, before its symlink or
# authorized_keys work. Other Git calls use real Git to check effective routing.
cat >"$test_root/bin/git" <<'SH'
#!/bin/sh
case "$1" in
  clone|fetch)
    printf '%s\n' "$*" >>"$TEST_LOG"
    [ "$GH_HOST" = github.com ] || exit 97
    [ "$("$REAL_GIT" ls-remote --get-url "$2")" = "$2" ] || exit 98
    exit 42;;
  *) exec "$REAL_GIT" "$@";;
esac
SH
cat >"$test_root/bin/curl" <<'SH'
#!/bin/sh
[ "$*" = "-fsSL --output $3 https://raw.githubusercontent.com/JonathanPorta/dotfiles/master/installation/include/public-github.sh" ] || exit 97
[ "$TEST_MODE" != download-failure ] || exit 22
cp "$REPO_ROOT/installation/include/public-github.sh" "$3"
SH
chmod +x "$test_root/bin/"*
for mode in local-clone local-fetch piped-clone download-failure; do
  case_home="$test_root/$mode"
  mkdir -p "$case_home"
  if [[ "$mode" == local-fetch ]]; then
    mkdir -p "$case_home/devel/tester/dotfiles"
    git init -q "$case_home/devel/tester/dotfiles"
    git -C "$case_home/devel/tester/dotfiles" remote add origin https://work.ghe.com/org/dotfiles
  fi
  : >"$test_root/calls"
  bootstrap_env=(env -i PATH="$test_root/bin:/usr/bin:/bin" HOME="$case_home" USER=tester \
    TMPDIR="$test_root/tmp" HEADLESS=true GH_HOST=work.ghe.com \
    GIT_CONFIG_GLOBAL="$test_root/gitconfig" GIT_CONFIG_NOSYSTEM=1 REAL_GIT="$real_git" \
    REPO_ROOT="$repo_root" TEST_LOG="$test_root/calls" TEST_MODE="$mode")
  result=0
  if [[ "$mode" == local-* ]]; then
    "${bootstrap_env[@]}" bash "$repo_root/init.sh" >"$test_root/output" 2>&1 || result=$?
  else
    "${bootstrap_env[@]}" bash <"$repo_root/init.sh" >"$test_root/output" 2>&1 || result=$?
  fi
  if [[ "$mode" == download-failure ]]; then
    [[ "$result" == 22 && ! -s "$test_root/calls" ]]
  else
    [[ "$result" == 42 ]] || { cat "$test_root/output"; echo "FAIL: $mode status $result"; exit 1; }
    if [[ "$mode" == local-fetch ]]; then
      grep -Fx 'fetch https://github.com/JonathanPorta/dotfiles.git +refs/heads/*:refs/remotes/origin/*' "$test_root/calls" >/dev/null
      [[ "$(git -C "$case_home/devel/tester/dotfiles" config remote.origin.url)" == https://work.ghe.com/org/dotfiles ]]
    else
      grep -Fx "clone https://github.com/JonathanPorta/dotfiles.git $case_home/devel/tester/dotfiles" "$test_root/calls" >/dev/null
    fi
  fi
  [[ -z "$(ls -A "$test_root/tmp")" ]] || { echo 'FAIL: bootstrap temporary file leaked'; exit 1; }
  echo "PASS: bootstrap $mode"
done
