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

- [ ] **2.0 Build the cmux settings generator helper** &nbsp; *Serves: AC-3*
  - [ ] 2.1 Create `dotfiles/helpers/generate_cmux_settings.sh` patterned on `dotfiles/helpers/generate_gitconfig.sh`. Use `#!/usr/bin/env bash` and `set -eo pipefail`.
  - [ ] 2.2 Implementation:
    - Resolve `SCRIPT_GENERATOR_PATH` like `generate_gitconfig.sh` does (for the header comment).
    - `mkdir -p "$HOME/.config/cmux"`.
    - Read `$HOME/dotfiles/cmux-settings.json`.
    - Substitute `__HOME__` → `$HOME` using `sed` with `|` as delimiter (paths contain `/`).
    - Write the result to `$HOME/.config/cmux/settings.json`, prepended with a header line block:
      ```
      // This settings.json was generated via $SCRIPT_GENERATOR_PATH.
      // Edit dotfiles/cmux-settings.json (the template), not this file.
      ```
    - Print one `Generating ...` line to stdout, mirroring `generate_gitconfig.sh`.
  - [ ] 2.3 `chmod +x dotfiles/helpers/generate_cmux_settings.sh`.
  - [ ] 2.4 Run it directly: `bash dotfiles/helpers/generate_cmux_settings.sh`; confirm rendered file.
  - **Validates when:**
    - `bash dotfiles/helpers/generate_cmux_settings.sh` exits 0.
    - `grep -c '__HOME__' "$HOME/.config/cmux/settings.json"` outputs `0`.
    - `head -2 "$HOME/.config/cmux/settings.json"` contains the literal substring `generated`.
    - `grep -F "$HOME/.sounds/cmux-notification.wav" "$HOME/.config/cmux/settings.json"` matches at least one line.
    - `sed 's://.*$::' "$HOME/.config/cmux/settings.json" | jq -e '.notifications.customSoundFilePath'` outputs the expanded path (string equal to `"$HOME/.sounds/cmux-notification.wav"`).
    - `[ -f "$HOME/.config/cmux/settings.json" ] && [ ! -L "$HOME/.config/cmux/settings.json" ]` — regular file, not a symlink.

- [ ] **3.0 Wire the cmux block into `installation/symlink.sh`** &nbsp; *Serves: AC-4, AC-5, AC-7*
  - [ ] 3.1 Append a new block to `installation/symlink.sh` after the existing helpers-symlink block. Match surrounding style (`echo` for status lines, `bash` syntax, no `set -e` change).
  - [ ] 3.2 Block contents:
    - `mkdir -p "$HOME/.sounds" "$HOME/.config/cmux"` (idempotent).
    - Wav symlink using helpers idiom: if `readlink "$HOME/.sounds/cmux-notification.wav"` already equals `$HOME/dotfiles/cmux-notification.wav`, skip. Else if a file/symlink is in the way, move to `*.old$NOW` and relink. Else just create the symlink.
    - Invoke `"$HOME/dotfiles/helpers/generate_cmux_settings.sh"` (this is the path it will have after install — `$HOME/dotfiles` is already a symlink to `$DOTFILES_CHECKOUT/dotfiles` per `init.sh`).
  - [ ] 3.3 First run: clean state (manually delete `~/.sounds/cmux-notification.wav` and `~/.config/cmux/settings.json` first), then `bash installation/symlink.sh`. Confirm artifacts.
  - [ ] 3.4 Second run: immediately re-run `bash installation/symlink.sh` without changing anything. Confirm idempotency: no new `.old<digits>` files.
  - [ ] 3.5 Confirm `~/Downloads/help.wav` is still byte-identical to repo copy after the back-to-back runs.
  - **Validates when:**
    - After first run: `readlink "$HOME/.sounds/cmux-notification.wav"` outputs `$HOME/dotfiles/cmux-notification.wav` (or its expanded form like `/Users/portaj/dotfiles/cmux-notification.wav`).
    - After first run: `[ -f "$HOME/.config/cmux/settings.json" ] && [ ! -L "$HOME/.config/cmux/settings.json" ]` succeeds.
    - After first run: `grep -c '__HOME__' "$HOME/.config/cmux/settings.json"` outputs `0`.
    - After second run: `ls -1 "$HOME/.sounds/" | grep -E '^cmux-notification\.wav\.old[0-9]+$'` outputs nothing.
    - After second run: `ls -1 "$HOME/.config/cmux/" | grep -E '^settings\.json\.old[0-9]+$'` outputs nothing.
    - `cmp "$HOME/Downloads/help.wav" dotfiles/dotfiles/cmux-notification.wav` exits 0 after both runs.

- [ ] **4.0 End-to-end install + cmux behavior verification** &nbsp; *Serves: AC-6*
  - [ ] 4.1 (Pre-check, AI-runnable) — confirm cmux app is installed: `[ -d /Applications/cmux.app ] || mdfind -name 'cmux.app' | head -1`. If cmux isn't installed, escalate to human; this AC cannot be tested otherwise.
  - [ ] 4.2 (Manual) Quit cmux fully (it may cache settings on launch).
  - [ ] 4.3 (Manual) Relaunch cmux. Open Settings UI; confirm no parse-error warning is shown and that `customSoundFilePath` field shows the resolved path (e.g. `/Users/portaj/.sounds/cmux-notification.wav`).
  - [ ] 4.4 (Manual) Trigger a notification through cmux's normal mechanism (e.g. complete a long-running command in a workspace, or whichever trigger cmux uses).
  - [ ] 4.5 (Manual) Confirm the custom `help.wav` plays — not the system default.
  - **Validates when:**
    - **AI-side:** cmux app is detectable on disk; rendered `~/.config/cmux/settings.json` parses with `jq` (already covered by 2.0 / 3.0); rendered path resolves to an existing file: `[ -f "$(sed 's://.*$::' "$HOME/.config/cmux/settings.json" | jq -r '.notifications.customSoundFilePath')" ]` exits 0.
    - **Human-side (cannot be AI-validated):** cmux launches without a settings-error dialog; cmux Settings UI displays the resolved path; the custom sound is audible when a notification fires.
  - **Limitation:** AI-only validation can confirm preconditions (file exists, is readable, path resolves) but cannot drive the cmux GUI or hear audio. Human verification is required for AC-6.

- [ ] **5.0 Document the new helper and install paths in `README.md`** &nbsp; *Serves: AC-9*
  - [ ] 5.1 Add a row to the Helpers table (at the location the table lives in `README.md`) for `generate_cmux_settings.sh` with a one-line description matching the style of existing rows.
  - [ ] 5.2 In the `init.sh` description block, extend the `Purpose` cell to mention that cmux settings are rendered into `~/.config/cmux/settings.json` and that `cmux-notification.wav` is symlinked into `~/.sounds/`.
  - [ ] 5.3 Add a one-line note (in the cmux row or a short paragraph after the Helpers table) that GUI edits to cmux settings are overwritten on next `init.sh` / `run.sh` invocation — this is intentional for v1.
  - **Validates when:**
    - `grep -F 'generate_cmux_settings.sh' README.md` matches at least one line.
    - `grep -F '~/.sounds' README.md` matches at least one line.
    - `grep -i -E 'cmux.*(setting|notification)' README.md` matches at least one line.

## Open Items Resolved at This Stage

| Open Question (from PRD) | Resolution |
|---|---|
| 1. Generator wiring | `symlink.sh` only. Do **not** source from `.profile`. |
| 2. Companion `sound` key | TBD via task 1.3 (schema lookup); fall-back is "uncomment only `customSoundFilePath` and let AC-6 catch it." |
| 3. GUI drift warning | Not in v1 — silent overwrite (matches `generate_gitconfig.sh`). README note in task 5.3 makes this explicit. |
| 4. Schema validation in generator | Not in v1 — `jq` parse check happens in task validations only. |
