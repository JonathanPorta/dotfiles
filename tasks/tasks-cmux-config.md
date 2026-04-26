# Tasks: cmux Config + Custom Notification Sound

> Generated from [PRD: cmux Config + Custom Notification Sound](prd-cmux-config.md)
> Gates passed: Gate 1 (codebase analysis), Gate 2 (acceptance criteria), Gate 3 (parent tasks).

## Acceptance Criteria Traceability

| AC   | Criterion                                                            | Tasks        |
|------|----------------------------------------------------------------------|--------------|
| AC-1 | Template contains `__HOME__/.sounds/cmux-notification.wav`           | 1.0          |
| AC-2 | Wav is valid RIFF + `cmp`-equal to source                            | 1.0          |
| AC-3 | Generator renders `__HOME__` → `$HOME` with header comment           | 2.0          |
| AC-4 | `symlink.sh` creates `~/.sounds/` + the wav symlink                  | 3.0          |
| AC-5 | `symlink.sh` is idempotent (no spurious `.old` files)                | 3.0          |
| AC-6 | cmux loads rendered settings and plays the custom sound (manual)     | 4.0          |
| AC-7 | `~/Downloads/help.wav` unchanged                                     | 1.0, 3.0     |
| AC-8 | `git check-ignore` matches none of the new files                     | 1.0          |
| AC-9 | README documents the new helper and `~/.sounds/`                     | 5.0          |

## Relevant Files

(Identified by reading the codebase, not guessing.)

### New
- `dotfiles/dotfiles/cmux-settings.json` — JSONC template for cmux settings (committed; never directly read by cmux).
- `dotfiles/dotfiles/cmux-notification.wav` — custom notification sound asset (committed binary).
- `dotfiles/helpers/generate_cmux_settings.sh` — renders the template into `~/.config/cmux/settings.json` at install time.

### Modified
- `installation/symlink.sh` — append a new block (`mkdir -p`, wav symlink, generator invocation).
- `README.md` — document the new helper and install destinations.

### Read-only references
- `dotfiles/helpers/generate_gitconfig.sh` — precedent for the generator pattern (heredoc, `$HOME` substitution, header comment).
- `installation/include/vars.sh` — exports `DOTFILES_CHECKOUT`, `NOW`, `OS` (already sourced by `symlink.sh`).
- `installation/include/lib.sh` — provides `echo_green`, `echo_cyan`, etc. (currently NOT sourced by `symlink.sh`; keep new block consistent — use plain `echo` like the rest of the file).
- `~/Downloads/help.wav` — source asset; must remain byte-identical after the feature is installed.
- `~/.config/cmux/settings.json` — current cmux config (will be replaced by the rendered output).

### Notes
- **No automated test framework.** Validation = shell commands + one human-in-the-loop check (AC-6).
- **No Makefile** (rule-07 deviation, documented in the PRD). Canonical command surface for this feature is `bash installation/symlink.sh`.
- The repo's `installation/symlink.sh` is `bash` (`#!/usr/bin/env bash` + `set -e`); new block must work under bash, not just zsh.
- `NOW=$(date -u +%s)` from `vars.sh` advances between runs only if at least 1 second elapses. The helpers idiom we're adopting avoids creating `.old$NOW` files in the steady state, so this isn't a problem.
- Run idempotency check with: `bash installation/symlink.sh && bash installation/symlink.sh` (back-to-back).

## Tasks

- [x] **1.0 Add the cmux template + sound asset to the repo** &nbsp; *Serves: AC-1, AC-2, AC-7, AC-8*
  - [x] 1.1 `cp ~/Downloads/help.wav dotfiles/dotfiles/cmux-notification.wav` (copy, not move).
  - [x] 1.2 Confirm the copy: `file` reports RIFF WAVE; `cmp` against source exits 0.
  - [x] 1.3 Fetched cmux schema. `notifications.sound` enum includes `"custom_file"` — that's the sentinel that tells cmux to use `customSoundFilePath`. Resolution: template sets BOTH `sound: "custom_file"` AND `customSoundFilePath`.
  - [x] 1.4 Created `dotfiles/dotfiles/cmux-settings.json`. Active `notifications` block has the two keys; the rest of the upstream cmux template is preserved as commented-out reference. Added a header note explaining the `__HOME__` placeholder.
  - [x] 1.5 **Validation strategy revised** by AI (per rule 04 ownership): the original `jq` after `sed`-strip approach fails because (a) the URL contains `//` so a naive sed mangles it, and (b) cmux's JSONC permits trailing commas which standard `jq` rejects. Replaced with literal `grep -F` checks for the active key/value lines, which is sufficient given AC-6 (cmux loads the rendered file) is the structural test. Documented in session state.
  - [x] 1.6 `git check-ignore` confirms neither new file is ignored (exit 1, no stdout).
  - [x] 1.7 Confirmed `~/Downloads/help.wav` size + mtime unchanged after the copy (`cp -p`, no move).
  - **Validates when (revised):**
    - `file dotfiles/dotfiles/cmux-notification.wav` output contains `RIFF` and `WAVE audio`. ✓
    - `cmp dotfiles/dotfiles/cmux-notification.wav ~/Downloads/help.wav` exits 0. ✓
    - `grep -c -F '"customSoundFilePath": "__HOME__/.sounds/cmux-notification.wav"' dotfiles/dotfiles/cmux-settings.json` outputs `1`. ✓
    - `grep -c -F '"sound": "custom_file"' dotfiles/dotfiles/cmux-settings.json` outputs `1`. ✓
    - `git check-ignore -v dotfiles/dotfiles/cmux-settings.json dotfiles/dotfiles/cmux-notification.wav` produces no stdout (exits 1). ✓
    - `stat -f '%z %m' ~/Downloads/help.wav` = `528296 1442468506` (matches pre-task). ✓

- [x] **2.0 Build the cmux settings generator helper** &nbsp; *Serves: AC-3*
  - [x] 2.1 Created `dotfiles/helpers/generate_cmux_settings.sh` (`#!/usr/bin/env bash`, `set -eo pipefail`).
  - [x] 2.2 Reads `$HOME/dotfiles/cmux-settings.json`, prepends 3-line generated-by header, sed-substitutes `__HOME__` → `$HOME` with `|` delimiter, writes to `$HOME/.config/cmux/settings.json`. Errors loudly if template missing.
  - [x] 2.3 `chmod +x` applied.
  - [x] 2.4 Ran directly via `bash $HOME/dotfiles/helpers/generate_cmux_settings.sh`; rendered file looks correct.
  - **Validates when (revised — `jq` step replaced with `grep -F`, see task 1.5 note):**
    - `bash $HOME/dotfiles/helpers/generate_cmux_settings.sh` exits 0. ✓
    - `grep -c '__HOME__' $HOME/.config/cmux/settings.json` outputs `0`. ✓
    - `head -2 $HOME/.config/cmux/settings.json` contains the literal substring `generated`. ✓
    - `grep -F "$HOME/.sounds/cmux-notification.wav" $HOME/.config/cmux/settings.json` matches one line. ✓
    - `grep -F '"sound": "custom_file"' $HOME/.config/cmux/settings.json` matches one line. ✓
    - `[ -f $HOME/.config/cmux/settings.json ] && [ ! -L $HOME/.config/cmux/settings.json ]` succeeds. ✓

- [x] **3.0 Wire the cmux block into `installation/symlink.sh`** &nbsp; *Serves: AC-4, AC-5, AC-7*
  - [x] 3.1 Appended new block at end of `installation/symlink.sh` (above the existing GPG comment), matching surrounding `echo` style and bash syntax.
  - [x] 3.2 Block does `mkdir -p` for both new dirs, helpers-idiom symlink for the wav, then invokes `$HOME/dotfiles/helpers/generate_cmux_settings.sh`.
  - [x] 3.3 First run from clean state: created `~/.sounds/cmux-notification.wav` symlink and rendered `~/.config/cmux/settings.json`.
  - [x] 3.4 Second run: helpers-idiom block hit "nothing to do" branch; generator overwrote settings (matches `generate_gitconfig.sh` semantics, accepted per OQ #3). Zero `.old<digits>` files.
  - [x] 3.5 `~/Downloads/help.wav` mtime/size unchanged across both runs; `cmp`-equal to repo copy.
  - **Validates when:**
    - After first run: `readlink ~/.sounds/cmux-notification.wav` = `/Users/portaj/dotfiles/cmux-notification.wav`. ✓
    - After first run: `[ -f ~/.config/cmux/settings.json ] && [ ! -L ~/.config/cmux/settings.json ]` succeeds. ✓
    - After second run: no `cmux-notification.wav.old*` in `~/.sounds/`. ✓
    - After second run: no `settings.json.old*` in `~/.config/cmux/`. ✓
    - `cmp ~/Downloads/help.wav /Users/portaj/dotfiles/cmux-notification.wav` exits 0 after both runs. ✓
    - `~/Downloads/help.wav` `stat -f '%z %m'` = `528296 1442468506` after both runs. ✓

- [x] **4.0 End-to-end install + cmux behavior verification** &nbsp; *Serves: AC-6*
  - [x] 4.1 cmux app located at `/Applications/cmux.app`.
  - [x] 4.2–4.5 (Manual, human-verified): cmux relaunched, settings loaded without errors, custom `help.wav` plays on notification. Confirmed by user "Yep" on 2026-04-26.
  - **Validates when:**
    - AI-side: cmux app present, rendered file exists as regular file, configured path resolves to repo wav via the symlink chain. ✓
    - Human-side: settings load without error; custom sound audible. ✓ (user confirmed)

- [x] **5.0 Document the new helper and install paths in `README.md`** &nbsp; *Serves: AC-9*
  - [x] 5.1 Added `generate_cmux_settings.sh` row to the Helpers table.
  - [x] 5.2 Extended the `init.sh` Purpose cell with the cmux symlink + render summary.
  - [x] 5.3 Added the GUI-overwrite caveat inline on the new helpers row (instead of a separate paragraph).
  - **Validates when:**
    - `grep -F 'generate_cmux_settings.sh' README.md` matches. ✓
    - `grep -F '~/.sounds' README.md` matches. ✓
    - `grep -i -E 'cmux.*(setting|notification)' README.md` matches. ✓

## Open Items Resolved at This Stage

| Open Question (from PRD) | Resolution |
|---|---|
| 1. Generator wiring | `symlink.sh` only. Do **not** source from `.profile`. |
| 2. Companion `sound` key | TBD via task 1.3 (schema lookup); fall-back is "uncomment only `customSoundFilePath` and let AC-6 catch it." |
| 3. GUI drift warning | Not in v1 — silent overwrite (matches `generate_gitconfig.sh`). README note in task 5.3 makes this explicit. |
| 4. Schema validation in generator | Not in v1 — `jq` parse check happens in task validations only. |
