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

mode_of() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

test_home="$test_root/home"
mkdir -p "$test_home/.claude" "$test_home/.codex"

# The optional wrapper must not abort bootstrap under a system Python that lacks
# tomllib. The explicit override makes the minimum-interpreter path deterministic
# on CI hosts whose /usr/bin/python3 version varies.
incompatible_python="$test_root/python-without-tomllib"
cat >"$incompatible_python" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "-c" ]; then
  exit 1
fi
echo "incompatible interpreter was invoked after the capability check" >&2
exit 99
SH
chmod +x "$incompatible_python"
deferred_home="$test_root/deferred-home"
deferred_output=$(HOME="$deferred_home" PYTHON3_BIN="$incompatible_python" \
  "$installer" 2>&1) || fail "incompatible Python made the optional installer fail"
grep -F 'Python 3.11+ with tomllib is unavailable' <<<"$deferred_output" >/dev/null || \
  fail "incompatible Python did not produce the deferral notice"
[ ! -e "$deferred_home/.claude/settings.json" ] || \
  fail "deferred install wrote Claude settings"
[ ! -e "$deferred_home/.codex/config.toml" ] || \
  fail "deferred install wrote Codex config"

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

# A renderer backup conflict is discovered before either config is written.
renderer_conflict_home="$test_root/renderer-conflict-home"
mkdir -p "$renderer_conflict_home/.claude" "$renderer_conflict_home/.codex"
printf '%s\n' '{"sentinel": "claude-before-conflict"}' \
  >"$renderer_conflict_home/.claude/settings.json"
printf '%s\n' 'model = "codex-before-conflict"' \
  >"$renderer_conflict_home/.codex/config.toml"
printf '%s\n' 'renderer-owned-by-user' \
  >"$renderer_conflict_home/.claude/statusline-command.sh"
printf '%s\n' 'different-existing-backup' \
  >"$renderer_conflict_home/.claude/statusline-command.sh.pre-agent-config"
cp "$renderer_conflict_home/.claude/settings.json" \
  "$test_root/renderer-conflict-claude-before.json"
cp "$renderer_conflict_home/.codex/config.toml" \
  "$test_root/renderer-conflict-codex-before.toml"
if HOME="$renderer_conflict_home" "$installer" >/dev/null 2>&1; then
  fail "installer accepted a conflicting renderer backup"
fi
cmp "$test_root/renderer-conflict-claude-before.json" \
  "$renderer_conflict_home/.claude/settings.json" || \
  fail "renderer conflict changed Claude settings before failure"
cmp "$test_root/renderer-conflict-codex-before.toml" \
  "$renderer_conflict_home/.codex/config.toml" || \
  fail "renderer conflict changed Codex config before failure"
grep -F 'renderer-owned-by-user' \
  "$renderer_conflict_home/.claude/statusline-command.sh" >/dev/null || \
  fail "renderer conflict changed the existing renderer"
grep -F 'different-existing-backup' \
  "$renderer_conflict_home/.claude/statusline-command.sh.pre-agent-config" >/dev/null || \
  fail "renderer conflict changed the existing backup"
[ ! -e "$renderer_conflict_home/.claude/settings.json.pre-agent-config" ] || \
  fail "renderer conflict created a Claude backup before failing"
[ ! -e "$renderer_conflict_home/.codex/config.toml.pre-agent-config" ] || \
  fail "renderer conflict created a Codex backup before failing"

# Render a representative Claude payload. The prrq fixture implements the
# public summary contract from prrq#45; a poison queue file proves
# the renderer never reaches into prrq's storage directly.
mkdir -p "$test_root/prrq" "$test_root/status-bin" "$test_root/base-bin"
ln -s "$(command -v jq)" "$test_root/status-bin/jq"
ln -s "$(command -v jq)" "$test_root/base-bin/jq"
cat >"$test_root/status-bin/prrq" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >"${PRRQ_CALL_LOG:?}"
[ "$#" -eq 2 ] && [ "$1" = summary ] && [ "$2" = --json ] || exit 64
[ -z "${PRRQ_SUMMARY_FAIL:-}" ] || exit 2
cat "${PRRQ_SUMMARY_FIXTURE:?}"
SH
chmod +x "$test_root/status-bin/prrq"

cat >"$test_root/prrq/queue.json" <<'JSON'
{"items":[{"status":"needs_review"},{"status":"needs_review"}]}
JSON
cat >"$test_root/prrq-summary.json" <<'JSON'
{"schema_version":1,"open":7,"counts":{"approved":1,"changed":1,"changes_requested":1,"needs_review":1,"error":1,"gated":1,"claimed":1,"blocked":1}}
JSON
printf '%s\n' 'not-json' >"$test_root/invalid-prrq-summary"

jq -n '{
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
}' >"$test_root/claude-status-payload.json"

status_base="Opus 4 | e:high | ctx:23%⚠ | 5h:1% | 7d:95% | PR#23 … | \$2.250 | Σ\$3.50 | Δ+12/-3 | example-org/example-repo"
status_home="$test_root/status-home"
breadcrumb_dir="$status_home/.local/state/claude-statusline"
breadcrumb_key=$(printf '%s' '/tmp/example-repo' | \
  { md5 -q 2>/dev/null || md5sum | cut -d' ' -f1; } | cut -c1-12)
breadcrumb="$breadcrumb_dir/claude-ctx-$breadcrumb_key.breadcrumb"
breadcrumb_victim="$test_root/breadcrumb-victim"
mkdir -p "$breadcrumb_dir"
chmod 755 "$breadcrumb_dir"
printf '%s\n' 'must-not-be-overwritten' >"$breadcrumb_victim"
cp "$breadcrumb_victim" "$test_root/breadcrumb-victim.before"
ln -s "$breadcrumb_victim" "$breadcrumb"

rendered=$(HOME="$status_home" \
  PATH="$test_root/status-bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  PRRQ_HOME="$test_root/prrq" \
  PRRQ_CALL_LOG="$test_root/prrq-call.log" \
  PRRQ_SUMMARY_FIXTURE="$test_root/prrq-summary.json" \
  "$repo_root/dotfiles/agent-config.d/claude/statusline-command.sh" \
  <"$test_root/claude-status-payload.json")
expected="$status_base | 🟢 1  🟡 1  🔴 1  ⚪ 1  🟠 1  ⚠️ 1  🔒 1  🚫 1"
[ "$rendered" = "$expected" ] || \
  fail "unexpected Claude status line: $rendered"
[ "$(cat "$test_root/prrq-call.log")" = "summary --json" ] || \
  fail "renderer invoked the wrong prrq command"
cmp -s "$test_root/breadcrumb-victim.before" "$breadcrumb_victim" || \
  fail "breadcrumb write followed a planted symlink"
[ -f "$breadcrumb" ] && [ ! -L "$breadcrumb" ] || \
  fail "breadcrumb was not replaced with a regular file"
[ "$(mode_of "$breadcrumb_dir")" = 700 ] || \
  fail "breadcrumb directory is not private"
[ "$(mode_of "$breadcrumb")" = 600 ] || \
  fail "breadcrumb file is not private"
grep -Eq '^23 unknown [0-9]+$' "$breadcrumb" || \
  fail "breadcrumb content contract changed"

jq '.context_window.used_percentage = 42 | .session_id = "fixture-session"' \
  "$test_root/claude-status-payload.json" >"$test_root/claude-status-updated.json"
HOME="$status_home" PATH="$test_root/base-bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  "$repo_root/dotfiles/agent-config.d/claude/statusline-command.sh" \
  <"$test_root/claude-status-updated.json" >/dev/null
grep -Eq '^42 fixture-session [0-9]+$' "$breadcrumb" || \
  fail "ordinary render did not update the private breadcrumb"

# Missing, older, failing, or malformed prrq installations are optional and
# must not break the rest of the status line.
without_prrq=$(HOME="$status_home" \
  PATH="$test_root/base-bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  "$repo_root/dotfiles/agent-config.d/claude/statusline-command.sh" \
  <"$test_root/claude-status-payload.json")
[ "$without_prrq" = "$status_base" ] || \
  fail "missing prrq changed the Claude status line"

failing_prrq=$(HOME="$status_home" \
  PATH="$test_root/status-bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  PRRQ_CALL_LOG="$test_root/prrq-call.log" \
  PRRQ_SUMMARY_FIXTURE="$test_root/prrq-summary.json" \
  PRRQ_SUMMARY_FAIL=1 \
  "$repo_root/dotfiles/agent-config.d/claude/statusline-command.sh" \
  <"$test_root/claude-status-payload.json")
[ "$failing_prrq" = "$status_base" ] || \
  fail "failing prrq changed the Claude status line"

invalid_prrq=$(HOME="$status_home" \
  PATH="$test_root/status-bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  PRRQ_CALL_LOG="$test_root/prrq-call.log" \
  PRRQ_SUMMARY_FIXTURE="$test_root/invalid-prrq-summary" \
  "$repo_root/dotfiles/agent-config.d/claude/statusline-command.sh" \
  <"$test_root/claude-status-payload.json")
[ "$invalid_prrq" = "$status_base" ] || \
  fail "invalid prrq JSON changed the Claude status line"

echo "PASS: agent config fragments merge safely and idempotently"
