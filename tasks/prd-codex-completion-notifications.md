# PRD: Codex Completion Notifications

## Summary

Sync a narrowly owned Codex TUI notification policy through the existing
`agent-config.d` installer. Machines with Codex installed should receive a ping
when an agent turn finishes, without treating every Auto-review approval check
as user-blocking input.

## Codebase Analysis

### Explored

- `installation/agent-config.sh` selects Python 3.11+ and invokes the shared agent-config installer.
- `dotfiles/helpers/install_agent_config.py` safely merges Claude JSON and the Codex `tui.status_line` setting.
- `dotfiles/agent-config.d/codex/50-status-line.toml` is the existing Codex fragment.
- `tests/test-agent-config.sh` covers preservation, preflight safety, backups, and idempotency.
- `README.md` documents the fragment model and `bash tests/test-agent-config.sh` as the validation command.

### Relevant Patterns

- Agent fragments are applied lexically and own only explicitly supported keys.
- Codex changes preserve all unrelated TOML bytes and create one recovery copy before the first write.
- The installer plans and validates changes before modifying either agent config.

### Constraints Discovered

- The standard library has no comment-preserving TOML writer, so Codex uses a narrow text merge.
- The current Codex fragment validator permits only `tui.status_line`.
- There is no Makefile; the repository's documented equivalent command surface is `bash tests/test-agent-config.sh`.

### Assumptions Confirmed

- Codex availability means an executable named `codex` is discoverable on `PATH`.
- The managed notification keys may be replaced; unrelated config and comments must remain untouched.
- `agent-turn-complete` is the desired event because `approval-requested` is noisy under Auto-review.

## Background

Codex's built-in TUI emits `approval-requested` notifications before automatic
approval review has decided whether a human is needed. cmux faithfully surfaces
those messages, creating false "needs input" alerts. Codex supports filtering
TUI notifications to `agent-turn-complete`, but that preference currently has to
be maintained manually on each machine.

## Goals

- Sync completion-only, unfocused-window Codex notifications.
- Preserve existing user configuration outside the explicitly managed keys.
- Leave Codex config untouched on machines where Codex is not installed.
- Keep repeated installer runs byte-identical.

## Non-Goals

- Distinguishing post-review human approvals from automatically reviewed approvals.
- Managing cmux notification policy or sound behavior.
- Replacing or symlinking the entire `~/.codex/config.toml` file.
- Adding a new package or TOML-writing dependency.

## Architecture & Approach

- Add `dotfiles/agent-config.d/codex/60-notifications.toml` with the managed notification values.
- Generalize the Codex fragment loader and text merge to support a small allowlist of `[tui]` keys.
- Detect Codex with `shutil.which("codex")`; skip Codex planning and writes when it is absent while continuing Claude setup.
- Extend `tests/test-agent-config.sh` with replacement, creation, absence, preservation, and repeated-run checks.
- Update `README.md` to document the synced notification policy and conditional behavior.

## Acceptance Criteria

- [ ] AC-1: When `codex` exists on `PATH`, the installer sets `tui.notifications` to `["agent-turn-complete"]` and `tui.notification_condition` to `"unfocused"`.
- [ ] AC-2: Existing unrelated Codex keys, tables, and comments remain unchanged; only managed TUI values are replaced or inserted.
- [ ] AC-3: When `codex` is absent, an existing Codex config remains byte-identical and an absent Codex config is not created.
- [ ] AC-4: A second installer run produces no byte changes to either agent config.
- [ ] AC-5: Invalid existing agent configuration still fails preflight without partial writes.
- [ ] AC-6: `bash tests/test-agent-config.sh` passes.

## Open Questions

None.
