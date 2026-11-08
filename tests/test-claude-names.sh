#!/usr/bin/env bash
# Tests dotfiles/claude-names.zsh against a stub cmux, in dry-run mode, so no
# Claude session is started and the real cmux is never asked.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/dotfiles/claude-names.zsh"
test_root=$(mktemp -d)
sleeper=
trap '[[ -n $sleeper ]] && { kill "$sleeper"; wait "$sleeper"; } 2>/dev/null; rm -rf "$test_root"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

command -v jq >/dev/null || fail "jq is required"

# A stub cmux that answers `cmux --json workspace list` with fixed workspaces.
mkdir -p "$test_root/bin" "$test_root/home/.claude/sessions" "$test_root/home/.claude-az/sessions"
cat >"$test_root/bin/cmux" <<'EOF'
#!/usr/bin/env bash
cat <<'JSON'
{"workspaces": [
  {"id": "W-SCRATCH", "title": "Scratch", "has_custom_title": true, "current_directory": "/x/drops"},
  {"id": "W-PMCP", "title": "pmcp", "has_custom_title": true, "current_directory": "/x/pmcp"},
  {"id": "W-PR", "title": "PR Console", "has_custom_title": true, "current_directory": "/x/review"},
  {"id": "W-CICD", "title": "CI/CD", "has_custom_title": true, "current_directory": "/x/blessed-cicd"},
  {"id": "W-AUTO", "title": "me@host:~/devel/porta-infra", "has_custom_title": false, "current_directory": "/x/porta-infra"}
]}
JSON
EOF
chmod +x "$test_root/bin/cmux"

# Run the given command line in a clean zsh with the script sourced.
# Usage: run <workspace id> <zsh command>
run() {
  HOME="$test_root/home" PATH="$test_root/bin:$PATH" CMUX_WORKSPACE_ID="$1" \
    CLAUDE_NAMES_DRY_RUN=1 zsh -f -c 'source "$1"; eval "$2"' zsh "$script" "$2"
}

expect() {
  local got
  got=$(run "$1" "$2")
  [[ $got == "$3" ]] || fail "$2 in $1: expected [$3], got [$got]"
}

# Workspace titles, as written; only '/' changes.
expect W-PMCP 'claude' "would run: env -u CLAUDE_CONFIG_DIR claude --name pmcp-00"
expect W-PR 'claude' "would run: env -u CLAUDE_CONFIG_DIR claude --name 'PR Console-00'"
expect W-CICD 'claude-az "fix it"' "would run: env CLAUDE_CONFIG_DIR=$test_root/home/.claude-az claude --name CI-CD-00 'fix it'"
expect W-AUTO 'claude' "would run: env -u CLAUDE_CONFIG_DIR claude --name porta-infra-00"

# Launches that keep Claude's default name.
expect W-SCRATCH 'claude' "would run: env -u CLAUDE_CONFIG_DIR claude"
expect '' 'claude' "would run: env -u CLAUDE_CONFIG_DIR claude"
expect W-UNKNOWN 'claude' "would run: env -u CLAUDE_CONFIG_DIR claude"
expect W-PMCP 'claude -n mine' "would run: env -u CLAUDE_CONFIG_DIR claude -n mine"
expect W-PMCP 'claude --resume' "would run: env -u CLAUDE_CONFIG_DIR claude --resume"
expect W-PMCP 'claude -c' "would run: env -u CLAUDE_CONFIG_DIR claude -c"
expect W-PMCP 'claude -p hi' "would run: env -u CLAUDE_CONFIG_DIR claude -p hi"
expect W-PMCP 'claude mcp list' "would run: env -u CLAUDE_CONFIG_DIR claude mcp list"

# Ordinals: the lowest number no live session holds, across both profiles.
sleep 300 &
sleeper=$!
printf '{"pid": %d, "name": "PR Console-00"}\n' "$sleeper" >"$test_root/home/.claude/sessions/a.json"
printf '{"pid": %d, "name": "PR Console-02"}\n' "$sleeper" >"$test_root/home/.claude-az/sessions/b.json"
printf '{"pid": %d, "name": "PR Console-xx"}\n' "$sleeper" >"$test_root/home/.claude/sessions/c.json"
printf '{"pid": %d, "name": "pmcp-00"}\n' 999999 >"$test_root/home/.claude/sessions/d.json"
expect W-PR 'claude' "would run: env -u CLAUDE_CONFIG_DIR claude --name 'PR Console-01'"
expect W-PMCP 'claude' "would run: env -u CLAUDE_CONFIG_DIR claude --name pmcp-00"

# Sourcing twice, as `source ~/.zshrc` does, still leaves working functions.
got=$(HOME="$test_root/home" PATH="$test_root/bin:$PATH" CMUX_WORKSPACE_ID=W-PMCP CLAUDE_NAMES_DRY_RUN=1 \
  zsh -f -c 'alias claude="env -u CLAUDE_CONFIG_DIR claude"; source "$1"; source "$1"; claude' zsh "$script")
[[ $got == "would run: env -u CLAUDE_CONFIG_DIR claude --name pmcp-00" ]] || fail "re-sourcing: got [$got]"

echo "PASS: claude-names"
