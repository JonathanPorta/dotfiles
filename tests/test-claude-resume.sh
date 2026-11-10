#!/usr/bin/env bash
# Tests cross-profile resume in dotfiles/claude-names.zsh against temporary
# profile directories and a stub `claude` that records its arguments and the
# CLAUDE_CONFIG_DIR it received. No real Claude session is ever started.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/dotfiles/claude-names.zsh"
test_root=$(mktemp -d)
trap 'chmod -R u+rwx "$test_root" 2>/dev/null; rm -rf "$test_root"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# HOME contains a space, so every transcript path does too.
home="$test_root/home dir"
mkdir -p "$test_root/bin" "$home/.claude/projects" "$home/.claude-az/projects"
cat >"$test_root/bin/claude" <<'EOF'
#!/usr/bin/env bash
{
  printf 'CONFIG=%s\n' "${CLAUDE_CONFIG_DIR-<unset>}"
  for a in "$@"; do printf 'ARG=%s\n' "$a"; done
} >"$STUB_LOG"
echo "stub-stdout"
EOF
chmod +x "$test_root/bin/claude"

ID_P=11111111-1111-4111-8111-111111111111   # personal only
ID_A=22222222-2222-4222-8222-222222222222   # Azimuth only
ID_B=33333333-3333-4333-8333-333333333333   # both
ID_N=44444444-4444-4444-8444-444444444444   # neither
ID_X=55555555-5555-4555-8555-555555555555   # two copies in Azimuth

mkdir -p "$home/.claude/projects/-Users-me-proj" "$home/.claude-az/projects/-Users-me-proj" "$home/.claude-az/projects/-Users-me-other"
touch "$home/.claude/projects/-Users-me-proj/$ID_P.jsonl" \
      "$home/.claude-az/projects/-Users-me-proj/$ID_A.jsonl" \
      "$home/.claude/projects/-Users-me-proj/$ID_B.jsonl" \
      "$home/.claude-az/projects/-Users-me-proj/$ID_B.jsonl" \
      "$home/.claude-az/projects/-Users-me-proj/$ID_X.jsonl" \
      "$home/.claude-az/projects/-Users-me-other/$ID_X.jsonl"
P_PATH="$home/.claude/projects/-Users-me-proj/$ID_P.jsonl"
A_PATH="$home/.claude-az/projects/-Users-me-proj/$ID_A.jsonl"

# Usage: run <claude|claude-az> <args...>; sets OUT, ERR, RC and LOG.
run() {
  local log="$test_root/stub.log" out="$test_root/out" err="$test_root/err"
  rm -f "$log"
  set +e
  env -i HOME="$home" PATH="$test_root/bin:/usr/bin:/bin" STUB_LOG="$log" \
    zsh -f -c 'source "$1"; shift; "$@"' zsh "$script" "$@" >"$out" 2>"$err"
  RC=$?
  set -e
  OUT=$(<"$out")
  ERR=$(<"$err")
  LOG=$( [[ -f $log ]] && cat "$log" || echo "<not launched>")
}

expect_launch() { # <label> <expected config> <expected args, one per line>
  local want_cfg=$2; shift 2
  local want
  want="CONFIG=$want_cfg"
  local a
  for a in "$@"; do want+=$'\n'"ARG=$a"; done
  [[ $RC == 0 ]] || fail "$label: exit $RC, stderr: $ERR"
  [[ $LOG == "$want" ]] || fail "$label: launched
$LOG
expected
$want"
  [[ $OUT == "stub-stdout" ]] || fail "$label: stdout was contaminated: [$OUT]"
}

expect_err_line() { # <label> <line>
  grep -qxF -- "$2" <<<"$ERR" || fail "$1: stderr lacks [$2]; got:
$ERR"
}

# --- own profile: UUID passes through unchanged, account follows the command
label="claude, session in personal"
run claude --resume "$ID_P"
expect_launch "$label" "<unset>" --resume "$ID_P"
expect_err_line "$label" "[resume] Looking for $ID_P in Claude..."
expect_err_line "$label" "[resume] Found in Claude: $P_PATH"
expect_err_line "$label" "[resume] Launching Claude (personal account)."

label="claude-az, session in Azimuth"
run claude-az --resume "$ID_A"
expect_launch "$label" "$home/.claude-az" --resume "$ID_A"

# --- other profile: UUID becomes the absolute path, account does NOT switch
label="claude-az, session only in personal"
run claude-az --resume "$ID_P"
expect_launch "$label" "$home/.claude-az" --resume "$P_PATH"
want_err="[resume] Looking for $ID_P in Claude-AZ...
[resume] Not found. Looking in Claude...
[resume] Found in Claude: $P_PATH
[resume] Launching Claude-AZ (Azimuth account)."
[[ $ERR == "$want_err" ]] || fail "$label: stderr was
$ERR
expected
$want_err"

label="claude, session only in Azimuth"
run claude --resume "$ID_A"
expect_launch "$label" "<unset>" --resume "$A_PATH"
expect_err_line "$label" "[resume] Found in Claude-AZ: $A_PATH"
expect_err_line "$label" "[resume] Launching Claude (personal account)."

# --- both profiles: the invoked profile wins
label="claude, session in both"
run claude --resume "$ID_B"
expect_launch "$label" "<unset>" --resume "$ID_B"
grep -q 'Not found' <<<"$ERR" && fail "$label: searched the other profile"
label="claude-az, session in both"
run claude-az --resume "$ID_B"
expect_launch "$label" "$home/.claude-az" --resume "$ID_B"

# --- neither: nonzero, nothing launched
for cmd in claude claude-az; do
  label="$cmd, session in neither"
  run $cmd --resume "$ID_N"
  [[ $RC == 1 ]] || fail "$label: exit $RC, want 1"
  [[ $LOG == "<not launched>" ]] || fail "$label: Claude was launched: $LOG"
  [[ -z $OUT ]] || fail "$label: stdout not empty: $OUT"
done
expect_err_line "claude-az, neither" "[resume] Session $ID_N not found in Claude-AZ or Claude."
run claude --resume "$ID_N"
expect_err_line "claude, neither" "[resume] Session $ID_N not found in Claude or Claude-AZ."

# --- the three accepted forms, and argument preservation
label="--resume=UUID form"
run claude-az "--resume=$ID_P" --model "my model"
expect_launch "$label" "$home/.claude-az" "--resume=$P_PATH" --model "my model"
label="-r UUID form, args around it with spaces"
run claude-az -p "hello world" -r "$ID_P" --output-format json "trailing arg"
expect_launch "$label" "$home/.claude-az" -p "hello world" -r "$P_PATH" --output-format json "trailing arg"

# --- ambiguous within the preferred profile: report candidates, do not launch
label="ambiguous in Azimuth"
run claude-az --resume "$ID_X"
[[ $RC == 2 ]] || fail "$label: exit $RC, want 2"
[[ $LOG == "<not launched>" ]] || fail "$label: launched"
expect_err_line "$label" "[resume] Session $ID_X is ambiguous in Claude-AZ; candidates:"
expect_err_line "$label" "  $home/.claude-az/projects/-Users-me-other/$ID_X.jsonl"
expect_err_line "$label" "  $home/.claude-az/projects/-Users-me-proj/$ID_X.jsonl"

# --- a lookup failure is not "not found"
label="unreadable profile"
chmod 000 "$home/.claude-az/projects"
run claude-az --resume "$ID_A"
chmod 755 "$home/.claude-az/projects"
[[ $RC == 2 ]] || fail "$label: exit $RC, want 2"
[[ $LOG == "<not launched>" ]] || fail "$label: launched"
expect_err_line "$label" "[resume] Could not search Claude-AZ for $ID_A: cannot read $home/.claude-az/projects"
grep -q 'not found in' <<<"$ERR" && fail "$label: reported as not found"

# --- a readable match beside an unreadable sibling project is not unique
for case in "personal:claude:$ID_P:.claude" "personal:claude-az:$ID_P:.claude" "azimuth:claude-az:$ID_A:.claude-az" "azimuth:claude:$ID_A:.claude-az"; do
  IFS=: read -r where cmd id prof <<<"$case"
  for hidden in no yes; do
    label="$cmd, $where match beside an unreadable sibling (hidden duplicate: $hidden)"
    sib="$home/$prof/projects/-Users-me-locked"
    mkdir -p "$sib"
    [[ $hidden == yes ]] && touch "$sib/$id.jsonl"
    chmod 000 "$sib"
    run $cmd --resume "$id"
    chmod 755 "$sib"; rm -rf "$sib"
    [[ $RC == 2 ]] || fail "$label: exit $RC, want 2"
    [[ $LOG == "<not launched>" ]] || fail "$label: launched $LOG"
    grep -qF "cannot read $sib" <<<"$ERR" || fail "$label: stderr does not name $sib: $ERR"
  done
done
# controls: the same matches with no unreadable sibling still launch
run claude-az --resume "$ID_P"; expect_launch "control: cross-profile single match" "$home/.claude-az" --resume "$P_PATH"
run claude-az --resume "$ID_X"; [[ $RC == 2 ]] && grep -q 'ambiguous' <<<"$ERR" || fail "control: readable duplicate is still ambiguous"

# --- pass-through cases: unchanged arguments, no [resume] chatter
for args in "--resume" "--resume my-session-name" "--resume $P_PATH" "--continue" "-c" "mcp list" "-p hi" "-r"; do
  label="pass-through: $args"
  # shellcheck disable=SC2086
  run claude-az $args
  # shellcheck disable=SC2086
  expect_launch "$label" "$home/.claude-az" $args
  [[ -z $ERR ]] || fail "$label: unexpected stderr: $ERR"
done
label="pass-through: no arguments"
run claude
expect_launch "$label" "<unset>"
label="pass-through: subcommand with a UUID argument"
run claude logs "$ID_P"
expect_launch "$label" "<unset>" logs "$ID_P"

echo "PASS: claude-resume"
