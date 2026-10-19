#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

cat >"$test_root/packages.zsh" <<'ZSH'
set -eu
source "$REPO_ROOT/installation/include/lib.sh"
public_github() { "$@"; }
fail() { print -u2 "FAIL: $*"; exit 1; }
brew() {
  case "$1" in
    list) [[ "$*" == 'list --formula --versions installed' ]] && print 'installed 1.0';;
    install) print -r -- "$*" >>"$TEST_LOG"; return "${INSTALL_RC:-0}";;
    *) return 98;;
  esac
}
rpm() { [[ "$*" == '-q -- installed' ]]; }
sudo() { print -r -- "$*" >>"$TEST_LOG"; return "${INSTALL_RC:-0}"; }
for OS in darwin linux; do
  : >"$TEST_LOG"
  pkg_install installed
  [[ ! -s "$TEST_LOG" ]] || fail "$OS reinstalled an installed package"
  pkg_install installed missing
  if [[ "$OS" == darwin ]]; then expected='install missing'; else expected='dnf install -y missing'; fi
  [[ "$(cat "$TEST_LOG")" == "$expected" ]] || fail "$OS mixed package filtering"
  : >"$TEST_LOG"
  INSTALL_RC=17
  if pkg_install missing; then fail 'install failure swallowed'; else [[ $? == 17 ]] || fail 'install status lost'; fi
  unset INSTALL_RC
done
OS=linux
: >"$TEST_LOG"
pkg_install gh --repo gh-cli
[[ "$(cat "$TEST_LOG")" == 'dnf install -y gh --repo gh-cli' ]] || fail 'dnf option/value lost'
: >"$TEST_LOG"
pkg_install installed --repo gh-cli
[[ ! -s "$TEST_LOG" ]] || fail 'dnf invoked with only options'
: >"$TEST_LOG"
pkg_install './local package.rpm' https://example.invalid/package.rpm
[[ "$(cat "$TEST_LOG")" == 'dnf install -y ./local package.rpm https://example.invalid/package.rpm' ]] || fail 'RPM paths lost'
print 'PASS: package filtering, options, and errors'
ZSH
env REPO_ROOT="$repo_root" TEST_LOG="$test_root/packages.log" zsh "$test_root/packages.zsh"

mkdir -p "$test_root/home/.local/bin" "$test_root/venv/bin" "$test_root/conda/bin" "$test_root/bin"
cat >"$test_root/bin/uname" <<'SH'
#!/bin/sh
echo Darwin
SH
cat >"$test_root/bin/brew" <<'SH'
#!/bin/sh
if [ "$*" = 'list --formula --versions python-build' ]; then echo 'python-build 1.6.1'; else echo "unexpected brew: $*" >>"$TEST_LOG"; exit 99; fi
SH
cat >"$test_root/home/.local/bin/uv" <<'SH'
#!/bin/sh
if [ -n "${VIRTUAL_ENV:-}${CONDA_PREFIX:-}" ]; then echo 'active environment leaked' >>"$TEST_LOG"; exit 98; fi
case "$PATH" in *"$TEST_ROOT/venv/bin"*|*"$TEST_ROOT/conda/bin"*) echo 'active PATH leaked' >>"$TEST_LOG"; exit 98;; esac
printf '%s\n' "$*" >>"$TEST_LOG"
case "$*" in
  'python find --system --no-project --no-python-downloads >=3.11'|'python find --system --no-project --no-python-downloads 3.12')
    if [ "${TEST_NO_PYTHON:-0}" = 1 ] && [ ! -f "$TEST_ROOT/python-installed" ]; then exit 1; fi
    printf '%s\n' "$TEST_ROOT/bin/python3";;
  'python install 3.12')
    [ "${TEST_PYTHON_FAILURE:-0}" = 0 ] || exit 18
    touch "$TEST_ROOT/python-installed";;
  'tool install '*)
    [ "${TEST_TOOL_FAILURE:-0}" = 0 ] || exit 19
    for tool; do :; done
    printf '#!/bin/sh\nexit 0\n' >"$HOME/.local/bin/$tool"
    chmod +x "$HOME/.local/bin/$tool";;
  *) exit 97;;
esac
SH
cat >"$test_root/bin/python3" <<'SH'
#!/bin/sh
echo 'Python 3.12.10'
SH
for forbidden in pip pip3 curl; do
  cat >"$test_root/bin/$forbidden" <<'SH'
#!/bin/sh
echo "unexpected command: $0 $*" >>"$TEST_LOG"
exit 99
SH
done
for tool in python3 uv virtualenv pipenv poetry; do
  printf '#!/bin/sh\necho "active environment executable used" >>"$TEST_LOG"\nexit 98\n' >"$test_root/venv/bin/$tool"
done
chmod +x "$test_root/bin/"* "$test_root/home/.local/bin/uv" "$test_root/venv/bin/"*

run_python() {
  env -i PATH="$test_root/venv/bin:$test_root/conda/bin:$test_root/bin:/usr/bin:/bin" \
    HOME="$test_root/home" VIRTUAL_ENV="$test_root/venv" CONDA_PREFIX="$test_root/conda" \
    INSTALLATION_SOURCE_DIR="$repo_root/installation" TEST_LOG="$test_root/python.log" \
    TEST_ROOT="$test_root" TEST_TOOL_FAILURE="${1:-0}" \
    TEST_NO_PYTHON="${2:-0}" TEST_PYTHON_FAILURE="${3:-0}" \
    zsh "$repo_root/installation/python3.sh"
}
: >"$test_root/python.log"
run_python >"$test_root/python.output" 2>&1 || { cat "$test_root/python.output" "$test_root/python.log"; exit 1; }
for tool in virtualenv pipenv poetry; do
  grep -Fx "tool install --python $test_root/bin/python3 $tool" "$test_root/python.log" >/dev/null
done
grep 'Python 3.12.10' "$test_root/python.output" >/dev/null
grep -E 'unexpected|leaked|executable used' "$test_root/python.log" && exit 1
grep '^python install ' "$test_root/python.log" && exit 1
: >"$test_root/python.log"
run_python >"$test_root/python.output" 2>&1
grep '^tool install ' "$test_root/python.log" && exit 1
rm "$test_root/home/.local/bin/virtualenv"
if run_python 1 >"$test_root/python.output" 2>&1; then echo 'FAIL: Python tool failure swallowed'; exit 1; fi
if run_python 0 1 1 >"$test_root/python.output" 2>&1; then echo 'FAIL: Python install failure swallowed'; exit 1; fi
: >"$test_root/python.log"
run_python 0 1 >"$test_root/python.output" 2>&1
grep -Fx 'python install 3.12' "$test_root/python.log" >/dev/null
mv "$test_root/home/.local/bin/uv" "$test_root/uv.fixture"
if run_python >"$test_root/python.output" 2>&1; then echo 'FAIL: uv download failure swallowed'; exit 1; fi
echo 'PASS: isolated Python tools, existing uv/Python, fallback, reruns, and errors'
