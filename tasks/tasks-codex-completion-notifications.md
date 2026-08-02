# Tasks: Codex Completion Notifications

> Generated from [PRD: Codex Completion Notifications](prd-codex-completion-notifications.md)

## Acceptance Criteria Traceability

| AC | Criterion | Tasks |
|---|---|---|
| AC-1 | Sync completion-only, unfocused notifications | 1.0 |
| AC-2 | Preserve unrelated Codex TOML | 1.0 |
| AC-3 | Skip Codex config when Codex is absent | 1.0 |
| AC-4 | Repeated runs are byte-identical | 1.0 |
| AC-5 | Preserve all-or-nothing preflight safety | 1.0 |
| AC-6 | Existing agent-config suite passes | 1.0 |

## Relevant Files

- `dotfiles/agent-config.d/codex/60-notifications.toml` — new notification fragment.
- `dotfiles/helpers/install_agent_config.py` — fragment validation, narrow TOML merge, and Codex presence gate.
- `installation/agent-config.sh` — optional-config deferral wording.
- `run.sh` — setup progress wording.
- `tests/test-agent-config.sh` — behavioral regression coverage.
- `README.md` — synced Codex behavior and conditional-install documentation.

### Notes

- No Makefile exists; use the repository-documented `bash tests/test-agent-config.sh` command.
- Validation review was required and approved by the human with "go" on 2026-08-02.

## Tasks

- [x] 1.0 Add safe Codex completion-notification sync <- Serves: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6
  - [x] 1.1 Add failing coverage for managed notification replacement and insertion.
  - [x] 1.2 Add failing coverage proving Codex absence causes no Codex writes.
  - [x] 1.3 Add the notification fragment and generalize the allowlisted TUI merge.
  - [x] 1.4 Gate Codex config planning on the executable being available.
  - [x] 1.5 Document the behavior and run the full agent-config suite.

  **Pre-implementation validation plan:**

  1. Change existing-config fixtures to contain noisy notification values; run the suite before implementation and require failure because the desired fragment is not yet supported.
  2. Add absent-Codex fixtures; require failure before implementation because the current installer writes Codex config unconditionally.
  3. After implementation, run `bash tests/test-agent-config.sh` and require the final PASS marker with exit status 0.
  4. Inspect the installed TOML semantically with `tomllib` and byte-wise with `cmp`/`grep` assertions already used by the suite.
  5. Run `python3 -m py_compile dotfiles/helpers/install_agent_config.py` and `bash -n tests/test-agent-config.sh installation/agent-config.sh`.
  6. Review `git diff --check`, the scoped diff, and repository status before committing.

  **Task 1.0 Preflight:**

  - Validation plan written: yes
  - Validation plan saved in artifact: yes
  - Validation review mode recorded in session state: required
  - Make targets or equivalent command surface identified: yes
  - Acceptance criteria served by this task listed: yes
  - Relevant files re-read before modification: yes

  **Validates when:**

  - All six acceptance criteria have direct automated evidence.
  - The complete agent-config suite exits 0 and reports PASS.
  - Static syntax and whitespace checks exit 0.

## Validation Results

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Notification tests fail before implementation | PASS | Initial suite exited 1 at the expected notification assertion. |
| 2 | Desired notification values replace noisy existing values | PASS | `tomllib` assertions verify `agent-turn-complete` and `unfocused`. |
| 3 | Missing Codex leaves existing/absent Codex config untouched | PASS | Byte comparison, backup absence, and file-absence assertions pass. |
| 4 | Unrelated config, comments, and all-or-nothing preflight survive | PASS | Existing preservation, invalid JSON/TOML, symlink, and backup-conflict cases pass. |
| 5 | Repeated installer run is byte-identical | PASS | Second-run `cmp` checks pass and installer reports both configs unchanged. |
| 6 | Full test suite | PASS | `bash tests/test-agent-config.sh` exits 0 with the final PASS marker. |
| 7 | Static checks | PASS | `bash -n ...` and `git diff --check` exit 0. |

### Phase-Gate Audit

**Result:** PASS

**Rules compliance:** Validation was approved and recorded before implementation; tests were written and observed red before the allowlisted merge was generalized.

**Listed done but not actually done:** None.

**Required but not done:** Remote publication remains human-owned under repository policy.

**Done differently than documented:** None.

**Documentation/state updates needed:** Temporary session state removed after completion; PRD and task evidence retained for review.

**Verification performed:** Full behavioral suite, shell syntax checks, and whitespace validation all pass.

**Recommended next action:** Review the local commit, then push the branch and open the prepared draft PR.
