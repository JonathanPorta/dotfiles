#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
command -v zsh >/dev/null

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

mode_of() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

# Format served by https://cli.github.com/packages/rpm/gh-cli.repo.
cat >"$test_root/valid.repo" <<'REPO'
[gh-cli]
name=packages for the GitHub CLI
baseurl=https://cli.github.com/packages/rpm
enabled=1
gpgcheck=1
gpgkey=https://cli.github.com/packages/githubcli-archive-keyring.asc
REPO
sed '/^gpgkey=/d' "$test_root/valid.repo" >"$test_root/truncated.repo"
sed 's/keyring.asc/keyring.a/' "$test_root/valid.repo" >"$test_root/partial-key.repo"
sed 's/gpgcheck=1/gpgcheck=0/' "$test_root/valid.repo" >"$test_root/unsigned.repo"
sed 's/githubcli-archive-keyring.asc/githubcli-archive-keyring-rotated.gpg/' \
  "$test_root/valid.repo" >"$test_root/rotated.repo"
printf '%s\n' '<html>Service unavailable</html>' >"$test_root/invalid.repo"
: >"$test_root/empty.repo"
printf '%s\n' '[gh-cli]' 'name=working repo sentinel' >"$test_root/before.repo"

# Run the actual installer and pkg_install function, mocking only external
# commands. sudo never executes: repository paths are mapped into the fixture.
cat >"$test_root/runner.zsh" <<'ZSH'
uname() { printf '%s\n' Linux; }
gh() { return 1; }
git() { return 0; }

curl() {
  local output_file=""
  while (( $# )); do
    case "$1" in
      -fsSL) shift ;;
      --output|-o) output_file="$2"; shift 2 ;;
      https://cli.github.com/packages/rpm/gh-cli.repo) shift ;;
      *) printf 'unexpected curl argument: %s\n' "$1" >>"$TEST_CALL_LOG"; return 99 ;;
    esac
  done
  if [[ -n "$output_file" ]]; then
    cat "$TEST_FIXTURE" >"$output_file"
  else
    cat "$TEST_FIXTURE"
  fi
  return "$TEST_CURL_RC"
}

sudo() {
  local operation="$1"
  shift
  case "$operation" in
    dnf)
      if [[ "$*" == 'install -y gh --repo gh-cli' ]]; then
        printf '%s\n' "$*" >>"$TEST_CALL_LOG"
        cmp -s "$TEST_FIXTURE" "$TEST_REPO_DIR/gh-cli.repo" || return 97
        [[ "$TEST_FAILURE" != dnf ]]
        return $?
      fi
      [[ "$1" == install || "$1" == remove ]] && return 0
      ;;
    tee)
      # Supports the old implementation so the regression fails on lost bytes.
      if [[ "$*" == /etc/yum.repos.d/gh-cli.repo ]]; then
        command tee "$TEST_REPO_DIR/gh-cli.repo"
        return $?
      fi
      ;;
    mktemp)
      if [[ "$*" == /etc/yum.repos.d/.gh-cli.repo.XXXXXX ]]; then
        command mktemp "$TEST_REPO_DIR/.gh-cli.repo.XXXXXX"
        return $?
      fi
      ;;
    install)
      if [[ $# == 4 && "$1" == -m && "$2" == 0644 && "$4" == "$TEST_REPO_DIR"/.gh-cli.repo.* ]]; then
        if [[ "$TEST_FAILURE" == stage ]]; then
          printf '%s\n' 'partial staging write' >"$4"
          return 1
        fi
        command install "$@"
        return $?
      fi
      ;;
    mv)
      if [[ $# == 3 && "$1" == -f && "$2" == "$TEST_REPO_DIR"/.gh-cli.repo.* && "$3" == /etc/yum.repos.d/gh-cli.repo ]]; then
        [[ "$TEST_FAILURE" != rename ]] || return 1
        command mv -f "$2" "$TEST_REPO_DIR/gh-cli.repo"
        return $?
      fi
      ;;
    rm)
      if [[ $# == 2 && "$1" == -f && "$2" == "$TEST_REPO_DIR"/.gh-cli.repo.* ]]; then
        command rm "$@"
        return $?
      fi
      ;;
  esac
  printf 'unexpected sudo command: %s %s\n' "$operation" "$*" >>"$TEST_CALL_LOG"
  return 99
}

source "$TEST_INSTALLER"
ZSH

run_case() {
  local label="$1" fixture="$2" curl_rc="$3" expected="$4"
  local failure="${5:-}" existing="${6:-yes}"
  local case_dir="$test_root/$label case"
  mkdir -p "$case_dir/repos" "$case_dir/downloads"
  if [[ "$existing" == yes ]]; then
    cp "$test_root/before.repo" "$case_dir/repos/gh-cli.repo"
  fi
  : >"$case_dir/calls"
  TEST_INSTALLER="$repo_root/installation/util.sh" \
    INSTALLATION_SOURCE_DIR="$repo_root/installation" \
    TEST_REPO_DIR="$case_dir/repos" TEST_CALL_LOG="$case_dir/calls" \
    TEST_FIXTURE="$test_root/$fixture.repo" TEST_CURL_RC="$curl_rc" \
    TEST_FAILURE="$failure" TMPDIR="$case_dir/downloads" \
    zsh -f "$test_root/runner.zsh" >"$case_dir/output" 2>&1 || \
    fail "$label: installer unexpectedly aborted"

  sed -n '/Installing gh cli for fedora/,/Skipping gh extensions/p' \
    "$case_dir/output" >"$case_dir/gh-output"
  if [[ "$expected" == skip ]]; then
    if [[ "$existing" == yes ]]; then
      cmp -s "$test_root/before.repo" "$case_dir/repos/gh-cli.repo" || \
        fail "$label: existing repository changed"
    else
      [[ ! -e "$case_dir/repos/gh-cli.repo" ]] || fail "$label: created an invalid repo"
    fi
    [[ ! -s "$case_dir/calls" ]] || fail "$label: reached installation or an unexpected command"
    grep -F 'Skipping gh repository refresh and installation' "$case_dir/gh-output" >/dev/null || \
      fail "$label: skipped refresh was not reported"
  else
    cmp -s "$test_root/$fixture.repo" "$case_dir/repos/gh-cli.repo" || \
      fail "$label: valid content was not installed"
    [[ "$(mode_of "$case_dir/repos/gh-cli.repo")" == 644 ]] || fail "$label: wrong repository mode"
    [[ "$(cat "$case_dir/calls")" == 'install -y gh --repo gh-cli' ]] || \
      fail "$label: did not use the common dnf4/dnf5 install command"
    if [[ "$expected" == install-failed ]]; then
      grep -F 'gh installation failed' "$case_dir/gh-output" >/dev/null || \
        fail "$label: package installation failure was not reported"
    fi
  fi
  if [[ "$expected" == success ]]; then
    grep -F 'Done.' "$case_dir/gh-output" >/dev/null || fail "$label: success was not reported"
  elif grep -F 'Done.' "$case_dir/gh-output" >/dev/null; then
    fail "$label: failure was reported as Done"
  fi
  [[ -z "$(find "$case_dir/downloads" -type f -print)" ]] || fail "$label: download was not cleaned up"
  [[ -z "$(find "$case_dir/repos" -name '.gh-cli.repo.*' -print)" ]] || fail "$label: staging was not cleaned up"
  echo "PASS: $label"
}

run_case failed-download empty 22 skip
run_case partial-download truncated 18 skip
run_case truncated-response truncated 0 skip
run_case truncated-key partial-key 0 skip
run_case invalid-response invalid 0 skip
run_case empty-response empty 0 skip
run_case disabled-signature-check unsigned 0 skip
run_case failed-first-download empty 22 skip '' no
run_case failed-staging valid 0 skip stage
run_case failed-rename valid 0 skip rename
run_case valid-refresh valid 0 success
run_case rotated-key rotated 0 success
run_case first-install valid 0 success '' no
run_case failed-install valid 0 install-failed dnf
