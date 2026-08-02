#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
installer="$repo_root/installation/agent-config.sh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

test_home="$test_root/home"
mkdir -p "$test_home/.claude" "$test_home/.codex"

cat >"$test_home/.claude/settings.json" <<'JSON'
{
  "permissions": {
    "allow": ["Bash(git status:*)"]
  },
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "keep-me"}]}]
  },
  "statusLine": {
    "type": "command",
    "command": "old-status-command"
  },
  "sentinel": "claude-settings-survived"
}
JSON

cat >"$test_home/.codex/config.toml" <<'TOML'
# preserve-this-comment
model = "sentinel-model"

[features]
hooks = true

[tui]
pet = "null-signal"
status_line = [
  "current-dir",
]
notifications = ["agent-turn-complete"]

[projects."/tmp/sentinel"]
trust_level = "trusted"
TOML

printf '%s\n' 'local-renderer-that-must-be-backed-up' \
  >"$test_home/.claude/statusline-command.sh"

HOME="$test_home" "$installer"

jq -e '.sentinel == "claude-settings-survived"' \
  "$test_home/.claude/settings.json" >/dev/null
jq -e '.permissions.allow == ["Bash(git status:*)"]' \
  "$test_home/.claude/settings.json" >/dev/null
jq -e '.hooks.Stop[0].hooks[0].command == "keep-me"' \
  "$test_home/.claude/settings.json" >/dev/null
jq -e '.statusLine.command == "bash \"$HOME/.claude/statusline-command.sh\""' \
  "$test_home/.claude/settings.json" >/dev/null

python3 - "$test_home/.codex/config.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as handle:
    config = tomllib.load(handle)

expected = [
    "model",
    "reasoning",
    "fast-mode",
    "context-used",
    "five-hour-limit",
    "weekly-limit",
    "pull-request-number",
    "branch-changes",
    "project-name",
]
assert config["model"] == "sentinel-model"
assert config["features"]["hooks"] is True
assert config["tui"]["pet"] == "null-signal"
assert config["tui"]["notifications"] == ["agent-turn-complete"]
assert config["tui"]["status_line"] == expected
assert config["projects"]["/tmp/sentinel"]["trust_level"] == "trusted"
PY

grep -F '# preserve-this-comment' "$test_home/.codex/config.toml" >/dev/null
[ -L "$test_home/.claude/statusline-command.sh" ] || fail "renderer is not a symlink"
[ "$(readlink "$test_home/.claude/statusline-command.sh")" = \
  "$repo_root/dotfiles/agent-config.d/claude/statusline-command.sh" ] || \
  fail "renderer symlink points to the wrong source"
grep -F 'local-renderer-that-must-be-backed-up' \
  "$test_home/.claude/statusline-command.sh.pre-agent-config" >/dev/null

cp "$test_home/.claude/settings.json" "$test_root/claude-first.json"
cp "$test_home/.codex/config.toml" "$test_root/codex-first.toml"
HOME="$test_home" "$installer"
cmp "$test_root/claude-first.json" "$test_home/.claude/settings.json" || \
  fail "second run changed Claude settings"
cmp "$test_root/codex-first.toml" "$test_home/.codex/config.toml" || \
  fail "second run changed Codex config"

# A missing [tui] table is appended without changing existing top-level data.
no_tui_home="$test_root/no-tui-home"
mkdir -p "$no_tui_home/.claude" "$no_tui_home/.codex"
printf '%s\n' '{"sentinel": "keep"}' >"$no_tui_home/.claude/settings.json"
printf '%s\n' 'model = "keep-me"' >"$no_tui_home/.codex/config.toml"
HOME="$no_tui_home" "$installer" >/dev/null
python3 - "$no_tui_home/.codex/config.toml" <<'PY'
import sys
import tomllib
with open(sys.argv[1], "rb") as handle:
    config = tomllib.load(handle)
assert config["model"] == "keep-me"
assert config["tui"]["status_line"][0] == "model"
PY

# Invalid inputs abort before either agent config is touched.
invalid_home="$test_root/invalid-home"
mkdir -p "$invalid_home/.claude" "$invalid_home/.codex"
printf '%s\n' '{ definitely not json' >"$invalid_home/.claude/settings.json"
printf '%s\n' 'model = "untouched"' >"$invalid_home/.codex/config.toml"
cp "$invalid_home/.claude/settings.json" "$test_root/invalid-before.json"
cp "$invalid_home/.codex/config.toml" "$test_root/invalid-before.toml"
if HOME="$invalid_home" "$installer" >/dev/null 2>&1; then
  fail "installer accepted invalid Claude JSON"
fi
cmp "$test_root/invalid-before.json" "$invalid_home/.claude/settings.json" || \
  fail "invalid Claude config was modified"
cmp "$test_root/invalid-before.toml" "$invalid_home/.codex/config.toml" || \
  fail "Codex config changed after Claude validation failed"

invalid_toml_home="$test_root/invalid-toml-home"
mkdir -p "$invalid_toml_home/.claude" "$invalid_toml_home/.codex"
printf '%s\n' '{"sentinel": "untouched"}' \
  >"$invalid_toml_home/.claude/settings.json"
printf '%s\n' '[tui' >"$invalid_toml_home/.codex/config.toml"
cp "$invalid_toml_home/.claude/settings.json" "$test_root/toml-claude-before.json"
cp "$invalid_toml_home/.codex/config.toml" "$test_root/toml-before.toml"
if HOME="$invalid_toml_home" "$installer" >/dev/null 2>&1; then
  fail "installer accepted invalid Codex TOML"
fi
cmp "$test_root/toml-claude-before.json" \
  "$invalid_toml_home/.claude/settings.json" || \
  fail "Claude config changed after Codex validation failed"
cmp "$test_root/toml-before.toml" "$invalid_toml_home/.codex/config.toml" || \
  fail "invalid Codex config was modified"

# Config symlinks are refused rather than replaced. This protects users who
# already manage an agent's whole config through another dotfiles mechanism.
symlink_home="$test_root/symlink-home"
mkdir -p "$symlink_home/.claude" "$symlink_home/.codex"
printf '%s\n' '{"sentinel": "external-config"}' >"$test_root/external.json"
ln -s "$test_root/external.json" "$symlink_home/.claude/settings.json"
printf '%s\n' 'model = "untouched"' >"$symlink_home/.codex/config.toml"
if HOME="$symlink_home" "$installer" >/dev/null 2>&1; then
  fail "installer replaced a symlinked config"
fi
grep -F 'external-config' "$test_root/external.json" >/dev/null
[ -L "$symlink_home/.claude/settings.json" ] || \
  fail "Claude config symlink was removed"

# Render a representative Claude payload, including the prrq queue summary.
mkdir -p "$test_root/prrq"
cat >"$test_root/prrq/queue.json" <<'JSON'
{
  "items": [
    {"status": "approved", "mergeable": "MERGEABLE", "ci_state": "SUCCESS"},
    {"status": "changed"},
    {"status": "changes_requested"},
    {"status": "needs_review"}
  ]
}
JSON
rendered=$(jq -n '{
  model: {display_name: "Opus 4", id: "claude-opus-4"},
  context_window: {
    used_percentage: 23,
    total_input_tokens: 100000,
    total_output_tokens: 10000
  },
  rate_limits: {
    five_hour: {used_percentage: 1},
    seven_day: {used_percentage: 95}
  },
  effort: {level: "high"},
  exceeds_200k_tokens: true,
  pr: {number: 23, review_state: "pending"},
  workspace: {
    repo: {owner: "example-org", name: "example-repo"},
    current_dir: "/tmp/example-repo"
  },
  cost: {
    total_cost_usd: 3.5,
    total_lines_added: 12,
    total_lines_removed: 3
  }
}' | PRRQ_HOME="$test_root/prrq" \
  "$repo_root/dotfiles/agent-config.d/claude/statusline-command.sh")
expected="Opus 4 | e:high | ctx:23%⚠ | 5h:1% | 7d:95% | PR#23 … | \$2.250 | Σ\$3.50 | Δ+12/-3 | example-org/example-repo | 🟢 1  🟡 1  🔴 1  ⚪ 1"
[ "$rendered" = "$expected" ] || \
  fail "unexpected Claude status line: $rendered"

echo "PASS: agent config fragments merge safely and idempotently"
