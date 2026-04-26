## Session State: cmux-config
Last updated: 2026-04-26

### Current Position
- **Current Phase:** Phase 3 — Validation-First Implementation
- **Validation Review Mode:** auto-proceed
- **Working on:** Task 4.0 — End-to-end cmux behavior verification (manual)
- **Status:** Tasks 1.0–3.0 complete and validated. Reconciliation audit after 2.0 passed.
- **Blocked:** No

### Key Decisions
Decisions made by the human (this session, 2026-04-26):

- Repo layout: flat — `dotfiles/dotfiles/cmux-settings.json` + `dotfiles/dotfiles/cmux-notification.wav`.
- Sound install path: `~/.sounds/cmux-notification.wav` (NOT `~/.helpers/sounds/`).
- Path portability: tokenized template (`__HOME__` → `$HOME`), rendered by helper.
- Source disposition for `~/Downloads/help.wav`: copy, leave original untouched.
- Repo filename for the wav: `cmux-notification.wav` (renamed from `help.wav`).
- Symlink idiom for new entries: helpers idiom (`readlink`-checked, idempotent).
- Generator wiring: `installation/symlink.sh` only — NOT sourced from `.profile`.
- GUI drift: silent overwrite acceptable for v1 (matches `generate_gitconfig.sh`).
- Schema validation in generator: not in v1.
- Validation review mode: auto-proceed (this session).

### Codebase Understanding
- `installation/symlink.sh` is `bash`, not `zsh`. Sources `include/vars.sh` (gives `DOTFILES_CHECKOUT`, `NOW`). Does NOT source `lib.sh`, so no `echo_green` / `echo_cyan` available in this file — keep new block to plain `echo`.
- `init.sh` already creates `$HOME/dotfiles` → `$DOTFILES_CHECKOUT/dotfiles` symlink early on, so `"$HOME/dotfiles/..."` paths are valid from `symlink.sh` onward.
- `generate_gitconfig.sh` pattern: heredoc-based, prepends a "generated, edit the source" header, writes a real file in `$HOME`, lives in `dotfiles/helpers/`, gets PATH'd via the `~/.helpers` symlink.
- **cmux schema lookup (task 1.3, resolved):** `notifications.sound` is an enum that includes `"custom_file"` — that sentinel tells cmux to use `customSoundFilePath`. Template MUST set both keys; setting only `customSoundFilePath` would be ignored.
- **JSONC validation gotcha (task 1.5):** the cmux schema URL contains `//` so naive `sed 's://.*$::'` mangles it; cmux JSONC permits trailing commas which strict `jq` rejects. Switched validation to `grep -F` literals; AC-6 (cmux loads the file) is the real structural test.
- No Makefile, no test framework. Canonical command surface = `bash installation/symlink.sh`. Validation = shell commands + 1 manual cmux GUI step (AC-6).
- `~/.config/cmux/settings.json` mode is `0600` and contents are entirely commented-out template — safe to commit.
- `~/Downloads/help.wav` original mtime/size: `1442468506` / `528296` bytes (Sep 16, 2015) — used as the "unchanged" baseline for AC-7 verification across all tasks.

### What's Next
1. Task 1.0 — fetch cmux schema (1.3), create both new files (1.1, 1.4), validate (1.2, 1.5–1.7).
2. Commit task 1.0.
3. Task 2.0 — write `generate_cmux_settings.sh` and validate.
4. Task 3.0 — wire into `installation/symlink.sh`; idempotency test.
5. Task 4.0 — manual cmux behavior verification (will require the human; AI-side preconditions only).
6. Task 5.0 — update `README.md`.
7. Reconciliation audits after task 2.0 and 4.0.
8. Final AC verification table + commit + sign-off request.

### Blockers / Open Questions
None blocking. PRD Open Question 2 (companion `sound` key) will be resolved during task 1.3 schema fetch.
