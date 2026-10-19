#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/home" "$test_root/tmp"
git config --file "$test_root/system" url.https://system.invalid/.insteadOf https://github.com/
git config --file "$test_root/global" include.path "$test_root/included"
git config --file "$test_root/included" url.https://enterprise.invalid/.insteadOf https://github.com/vilmibm/
git config --file "$test_root/included" http.proxy http://proxy.invalid:8080
git config --file "$test_root/included" http.sslCAInfo '/path with spaces/corporate.pem'
git config --file "$test_root/included" url.ssh://git@internal.invalid/.insteadOf https://internal.invalid/
git config --file "$test_root/included" --add credential.helper first
git config --file "$test_root/included" --add credential.helper second
printf '[test]\n  enabled\n' >>"$test_root/included"
cp "$test_root/global" "$test_root/global.before"
cp "$test_root/included" "$test_root/included.before"

cat >"$test_root/runner" <<'SHELL'
set -eu
if [ -f "$REPO_ROOT/installation/include/public-github.sh" ]; then
  . "$REPO_ROOT/installation/include/public-github.sh"
else
  public_github() { "$@"; }
fi
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
url=https://github.com/vilmibm/gh-screensaver
[ "$(git ls-remote --get-url "$url")" = https://enterprise.invalid/gh-screensaver ] || fail 'bad rewrite fixture'
[ "$(public_github git ls-remote --get-url "$url")" = "$url" ] || fail 'public URL was rewritten'
[ "$(public_github git config http.proxy)" = http://proxy.invalid:8080 ] || fail 'proxy lost'
[ "$(public_github git config http.sslCAInfo)" = '/path with spaces/corporate.pem' ] || fail 'CA lost'
[ "$(public_github git config --get-all credential.helper)" = "$(printf 'first\nsecond')" ] || fail 'multi-value config lost'
[ "$(public_github git config --bool test.enabled)" = true ] || fail 'bare boolean lost'
[ "$(public_github sh -c 'umask')" = "$(sh -c 'umask')" ] || fail 'child umask changed'
[ "$(public_github git ls-remote --get-url https://internal.invalid/team/tap)" = ssh://git@internal.invalid/team/tap ] || fail 'unrelated rewrite lost'

# The child process must inherit the filtered config, even with command-scope
# overrides. Values and argument boundaries survive; the caller is untouched.
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=url.https://command.invalid/.insteadOf
export GIT_CONFIG_VALUE_0=https://github.com/
export GIT_CONFIG_KEY_1=test.message
export GIT_CONFIG_VALUE_1='two words'
public_github sh -c '
  [ "$GH_HOST" = github.com ] && [ "${GH_REPO-unset}" = unset ] &&
  [ "${GH_TOKEN-unset}" = unset ] && [ "${GITHUB_TOKEN-unset}" = unset ] &&
  [ "$(git ls-remote --get-url "$1")" = "$1" ] &&
  [ "$(git config test.message)" = "two words" ] &&
  [ "$2" = "argument with spaces" ]
' sh "$url" 'argument with spaces' || fail 'child config, host, credentials, or arguments'
[ "$GH_HOST" = work.ghe.com ] && [ "$GH_REPO" = work.ghe.com/org/work ] || fail 'parent host changed'
[ "$GIT_CONFIG_COUNT" = 2 ] && [ "$GH_TOKEN" = enterprise-fixture ] || fail 'parent environment changed'
if public_github sh -c 'exit 23'; then fail 'failure swallowed'; else [ "$?" = 23 ] || fail 'exit code changed'; fi
[ -z "$(ls -A "$TMPDIR")" ] || fail 'temporary config leaked'
[ "$(git ls-remote --get-url "$url")" = https://enterprise.invalid/gh-screensaver ] || fail 'parent Git routing changed'
GH_HOST=github.com public_github sh -c '[ "$GH_TOKEN" = enterprise-fixture ]' || fail 'explicit public token lost'
printf 'PASS: public GitHub routing (%s)\n' "$TEST_SHELL"
SHELL

for test_shell in bash zsh; do
  env -i PATH="$PATH" HOME="$test_root/home" TMPDIR="$test_root/tmp" \
    GIT_CONFIG_SYSTEM="$test_root/system" GIT_CONFIG_GLOBAL="$test_root/global" \
    GH_HOST=work.ghe.com GH_REPO=work.ghe.com/org/work GH_TOKEN=enterprise-fixture GITHUB_TOKEN=enterprise-fixture \
    REPO_ROOT="$repo_root" TEST_SHELL="$test_shell" "$test_shell" "$test_root/runner"
done
cmp "$test_root/global" "$test_root/global.before"
cmp "$test_root/included" "$test_root/included.before"
