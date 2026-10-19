#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
test_root=$(cd "$test_root" && pwd -P)

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

# F1: includes activated by the caller's repository must not be made global.
# These are test canaries only; this suite never makes a network request.
git init -q "$test_root/work repo"
mkdir "$test_root/work repo/tmp"
mkdir "$test_root/work repo/tmp:ambiguous-ceiling"
git config --file "$test_root/global" "includeIf.gitdir:$test_root/work repo/.git.path" "$test_root/work-credentials"
git config --file "$test_root/work-credentials" http.extraHeader 'AUTHORIZATION: Bearer work-repo-canary'
git config --file "$test_root/work-credentials" credential.helper work-repo-helper
git config --file "$test_root/global" http.https://github.com/.extraHeader 'AUTHORIZATION: Bearer public-host-canary'
git config --file "$test_root/global" http.https://internal.invalid/.extraHeader 'AUTHORIZATION: Bearer internal-host-canary'
cp "$test_root/global" "$test_root/global.before"
cp "$test_root/included" "$test_root/included.before"
cp "$test_root/work-credentials" "$test_root/work-credentials.before"

cat >"$test_root/runner" <<'SHELL'
set -eu
if [ -f "$REPO_ROOT/installation/include/public-github.sh" ]; then
  . "$REPO_ROOT/installation/include/public-github.sh"
else
  public_github() { "$@"; }
fi
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
if (cd "$OUTSIDE_REPO" && git config --get-all http.extraheader >/dev/null); then
  fail 'work authorization was already visible outside its repository'
fi
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

# The temp directory is deliberately inside the work repo, so merely changing
# directory is insufficient: snapshotting must also stop repository discovery.
for repo_context in discovered explicit config-file; do
  (
    cd "$WORK_REPO"
    export TMPDIR="$WORK_REPO/tmp"
    if [ "$repo_context" = explicit ]; then
      export GIT_DIR="$WORK_REPO/.git" GIT_WORK_TREE="$WORK_REPO" GIT_COMMON_DIR="$WORK_REPO/.git"
    elif [ "$repo_context" = config-file ]; then
      export GIT_CONFIG="$WORK_CREDENTIALS"
    fi
    [ "$(git config --get-all http.extraheader)" = 'AUTHORIZATION: Bearer work-repo-canary' ] || fail 'bad conditional credential fixture'
    public_github sh -c '
      cd "$1" || exit 1
      # Check both effective child config and the generated global file. No
      # work-only header/helper may survive even when Git is explicitly pointed
      # at the original repository by the caller environment.
      if git config --get-all http.extraheader >/dev/null; then exit 1; fi
      if git config --file "$GIT_CONFIG_GLOBAL" --get-all http.extraheader >/dev/null; then exit 1; fi
      [ "$(git config --get-all credential.helper)" = "$(printf "first\nsecond")" ] &&
      [ "$(git config --get-urlmatch http.extraheader https://github.com/vilmibm/gh-screensaver)" = "AUTHORIZATION: Bearer public-host-canary" ] &&
      [ "$(git config --get-urlmatch http.extraheader https://internal.invalid/team/work)" = "AUTHORIZATION: Bearer internal-host-canary" ] &&
      ! git config --get-urlmatch http.extraheader https://unrelated.invalid/ >/dev/null &&
      [ "$(git config http.proxy)" = http://proxy.invalid:8080 ] &&
      [ "$(git config http.sslCAInfo)" = "/path with spaces/corporate.pem" ] &&
      [ "$(git ls-remote --get-url https://internal.invalid/team/tap)" = ssh://git@internal.invalid/team/tap ] &&
      [ "$(git ls-remote --get-url https://github.com/vilmibm/gh-screensaver)" = https://github.com/vilmibm/gh-screensaver ]
    ' sh "$OUTSIDE_REPO" || fail "conditional credentials escaped or host/transport boundaries changed ($repo_context)"
    [ "$(git config --get-all http.extraheader)" = 'AUTHORIZATION: Bearer work-repo-canary' ] || fail 'work credentials changed'
    [ -z "$(ls -A "$TMPDIR")" ] || fail 'work temp config leaked'
  ) || exit 1
done
# Colons delimit ceiling entries. If a temp path prevents isolation, fail
# before invoking the public command rather than copying repository credentials.
if TMPDIR="$WORK_REPO/tmp:ambiguous-ceiling" public_github sh -c 'echo invoked' >"$OUTSIDE_REPO/failed-snapshot" 2>"$OUTSIDE_REPO/snapshot-error"; then
  fail 'unisolated snapshot was accepted'
fi
[ ! -s "$OUTSIDE_REPO/failed-snapshot" ] || fail 'command ran after snapshot isolation failed'
grep -F 'Cannot isolate public GitHub configuration' "$OUTSIDE_REPO/snapshot-error" >/dev/null || fail 'unexpected snapshot failure'
[ -z "$(ls -A "$WORK_REPO/tmp:ambiguous-ceiling")" ] || fail 'failed snapshot leaked temporary files'
printf 'PASS: public GitHub routing (%s)\n' "$TEST_SHELL"
SHELL

failed=0
for test_shell in bash zsh; do
  if ! env -i PATH="$PATH" HOME="$test_root/home" TMPDIR="$test_root/tmp" \
    GIT_CONFIG_SYSTEM="$test_root/system" GIT_CONFIG_GLOBAL="$test_root/global" \
    GH_HOST=work.ghe.com GH_REPO=work.ghe.com/org/work GH_TOKEN=enterprise-fixture GITHUB_TOKEN=enterprise-fixture \
    WORK_REPO="$test_root/work repo" WORK_CREDENTIALS="$test_root/work-credentials" OUTSIDE_REPO="$test_root/home" \
    REPO_ROOT="$repo_root" TEST_SHELL="$test_shell" "$test_shell" "$test_root/runner"; then
    failed=1
  fi
done
cmp "$test_root/global" "$test_root/global.before"
cmp "$test_root/included" "$test_root/included.before"
cmp "$test_root/work-credentials" "$test_root/work-credentials.before"
exit "$failed"
