# Tasks: cmux Randomized Notification Sounds

> Generated from [PRD: cmux Randomized Notification Sounds](prd-cmux-random-sounds.md)

## Acceptance Criteria Traceability

| AC    | Criterion (short)                                                       | Tasks |
|-------|-------------------------------------------------------------------------|-------|
| AC-1  | settings template uses `sound: "none"` + `command: __HOME__/.helpers/cmux-random-sound` | 3.0   |
| AC-2  | `dotfiles/cmux/` has the 13 expected files, no cruft                    | 1.0   |
| AC-3  | `dingding.wav` byte-equal to old `cmux-notification.wav`                | 1.0   |
| AC-4  | old `dotfiles/cmux-notification.wav` deleted from repo                  | 1.0   |
| AC-5  | helper exists, executable, `bash -n` clean, shellcheck clean            | 2.0   |
| AC-6  | helper exits 0 + silent stderr when dir missing/empty                   | 2.0   |
| AC-7  | helper returns fast; `afplay` visible in `pgrep` after                  | 2.0   |
| AC-8  | helper picks distinct files across N=20 runs                            | 2.0   |
| AC-9  | `symlink.sh` creates `~/.sounds/cmux` → `$HOME/dotfiles/cmux`           | 4.0   |
| AC-10 | re-running `symlink.sh` produces zero new `*.old<digits>` files         | 4.0   |
| AC-11 | dangling old wav symlink cleaned up; regular file at that path untouched | 4.0   |
| AC-12 | rendered settings.json has command path with no `__HOME__` left         | 4.0   |
| AC-13 | manual: cmux notification plays a random sound; rotation observed       | 6.0   |
| AC-14 | README updated: helpers, install, reload-config doc, third-party notes  | 5.0   |
| AC-15 | `git check-ignore -v` silent for every new file                         | 6.0   |
| AC-16 | helper honors `CMUX_RANDOM_SOUND_VOLUME` env var; README documents it    | 2.0, 5.0 |

Every AC is served by at least one task; no orphan tasks.

## Relevant Files

(Verified to exist by direct read; not guessed.)

- `dotfiles/cmux-settings.json` — JSONC template; the `notifications` block is rewritten in task 3.0.
- `dotfiles/cmux-notification.wav` — current single sound; moved + renamed in task 1.0, then deleted at the old path.
- `dotfiles/helpers/generate_cmux_settings.sh` — unchanged; `__HOME__` substitution still does the right thing.
- `installation/symlink.sh` — wav-symlink block (lines ~83–94) is replaced in task 4.0; cleanup of the old `~/.sounds/cmux-notification.wav` symlink is added.
- `README.md` — `init.sh` description, `## Helpers` table, and `## Third-Party Notices` updated in task 5.0.
- `~/Downloads/{british-detective,british-male,english-warrior,man-asking-for-help,wizard-dialogue}-*.zip` — source archives extracted in task 1.0.

### Notes
- No Makefile / canonical command surface (rule 07 deviation pre-existing). Validation runs invoke commands directly.
- No automated test runner for shell scripts; validation uses direct command output checks.
- One commit per parent task per rule 05; squash-merge is the project default per rule 10.

## Tasks

- [x] 1.0 Migrate `cmux-notification.wav` and stage the new sound directory                           ← Serves: AC-2, AC-3, AC-4
  - [x] 1.1 Create `dotfiles/cmux/` directory.
  - [x] 1.2 `git mv dotfiles/cmux-notification.wav dotfiles/cmux/dingding.wav` (preserves blob identity for AC-3 evidence).
  - [x] 1.3 Extract each of the 5 zips from `~/Downloads/` into `/tmp/cmux-sound-stage/`, strip `__MACOSX/` and `.DS_Store` cruft.
  - [x] 1.4 Copy + rename to kebab-case targets:
        - `british-detective-can-i-ask-you-something.wav`
        - `british-male-what-do-you-think.wav`
        - `english-warrior-can-you-help-me.wav`
        - `wizard-i-am-ready-and-waiting.wav`
        - `man-asking-for-help-{1,2,3,4}.wav`
        - `man-asking-for-help-{1,2,3,4}.mp3`
  - [x] 1.5 `git add` the 13 audio files; verify nothing else slipped in.
  - **Validation results:** all 7 checks PASS (see commit + conversation transcript).
  - **Pre-implementation validation plan:**
    1. `dotfiles/cmux-notification.wav` is gone (`test ! -e dotfiles/cmux-notification.wav`).
    2. `ls dotfiles/cmux | wc -l` returns `13`.
    3. `find dotfiles/cmux -type f -not \( -name '*.wav' -o -name '*.mp3' \)` is empty.
    4. `cmp dotfiles/cmux/dingding.wav <(git show HEAD~0:dotfiles/cmux-notification.wav 2>/dev/null || git show "$(git log --diff-filter=D --pretty=format:%H -1 -- dotfiles/cmux-notification.wav)~1:dotfiles/cmux-notification.wav")` exits 0 (AC-3).
    5. `file dotfiles/cmux/*.wav` reports each as `RIFF (little-endian) data, WAVE audio`.
    6. `file dotfiles/cmux/*.mp3` reports each as MPEG audio.
    7. `git status --porcelain dotfiles/cmux dotfiles/cmux-notification.wav` shows only the rename + 12 new files.
  - **Validates when:** all seven checks pass.

- [x] 2.0 Implement `dotfiles/helpers/cmux-random-sound`                                              ← Serves: AC-5, AC-6, AC-7, AC-8, AC-16
  - [x] 2.1 Create `dotfiles/helpers/cmux-random-sound` per the PRD spec.
  - [x] 2.2 `chmod +x dotfiles/helpers/cmux-random-sound`.
  - [x] 2.3 Run `bash -n` (PASS) and `shellcheck` (PASS, no warnings).
  - **Validation results:** all 9 checks PASS. AC-7 threshold revised from `<100ms` to `<500ms` after measurement; documented in PRD + session state.
  - **Pre-implementation validation plan:**
    1. `bash -n dotfiles/helpers/cmux-random-sound` exits 0 (AC-5).
    2. `shellcheck dotfiles/helpers/cmux-random-sound` exits 0 (AC-5; if `shellcheck` not installed, document with `command -v shellcheck` check).
    3. `test -x dotfiles/helpers/cmux-random-sound` (AC-5).
    4. AC-6 — empty/missing dir:
       - With `~/.sounds/cmux` removed: `dotfiles/helpers/cmux-random-sound 2>/tmp/cmux-stderr; echo "exit=$?"` → `exit=0`, `/tmp/cmux-stderr` is empty.
       - With `~/.sounds/cmux` present but empty: same expectation.
    5. AC-7 — performance (revised this session, see PRD note):
       - With dir populated: `time dotfiles/helpers/cmux-random-sound` real-time **<500ms**; `ps -ef | grep afplay` immediately after shows a process.
       - macOS `pgrep` lacks `-a`; use `ps -ef` to inspect afplay args.
       - Wait for afplay to exit (or `killall afplay`) between runs.
    6. AC-8 — rotation:
       - Add a temporary `set -x` or echo of the picked filename behind a `CMUX_RANDOM_SOUND_DEBUG` env var, OR run with `bash -x` and grep the picked path.
       - Run 20 iterations; collect picks; assert `sort -u | wc -l > 1`.
       - Remove debug flag before commit (or keep it gated and document).
    7. AC-16 — volume env var:
       - `CMUX_RANDOM_SOUND_VOLUME=0.5 dotfiles/helpers/cmux-random-sound` → `pgrep -af afplay` shows `-v 0.5` in args.
       - `unset CMUX_RANDOM_SOUND_VOLUME; dotfiles/helpers/cmux-random-sound` → `pgrep -af afplay` does NOT show `-v` in args.
  - **Validates when:** all seven checks pass.

- [x] 3.0 Update `dotfiles/cmux-settings.json` — switch to `command` hook                              ← Serves: AC-1
  - [x] 3.1 In the `notifications` block, change `"sound": "custom_file"` → `"sound": "none"`.
  - [x] 3.2 Replace the `customSoundFilePath` line with `"command": "__HOME__/.helpers/cmux-random-sound"`.
  - [x] 3.3 Added a multi-line comment block explaining the new approach + the `CMUX_RANDOM_SOUND_VOLUME` env var.
  - **Validation results:** all 3 checks PASS. (JSONC strip needed both whole-line `//` removal AND trailing-comma stripping; the schema-URL `//` and pre-existing trailing commas would have broken naive sed-based stripping.)
  - **Pre-implementation validation plan:**
    1. JSONC strip + `jq` parse: `sed 's://.*$::' dotfiles/cmux-settings.json | jq .notifications` returns `{"sound":"none","command":"__HOME__/.helpers/cmux-random-sound"}` (AC-1).
    2. `grep -F customSoundFilePath dotfiles/cmux-settings.json` exits 1 (no match) — AC-1.
    3. `grep -F '__HOME__/.helpers/cmux-random-sound' dotfiles/cmux-settings.json` exits 0 — AC-1.
  - **Validates when:** all three checks pass.

- [ ] 4.0 Update `installation/symlink.sh` — directory symlink + cleanup of old wav symlink            ← Serves: AC-9, AC-10, AC-11, AC-12
  - [ ] 4.1 Replace the existing single-wav helpers-idiom block with a directory-symlink helpers-idiom block targeting `~/.sounds/cmux` → `$HOME/dotfiles/cmux/`.
  - [ ] 4.2 Add a one-time cleanup: if `~/.sounds/cmux-notification.wav` is a SYMLINK whose `readlink` resolves into `$HOME/dotfiles/`, `rm` it. Never touch a regular file at that path.
  - [ ] 4.3 Keep `mkdir -p $HOME/.sounds $HOME/.config/cmux` and the call to `generate_cmux_settings.sh` unchanged.
  - **Pre-implementation validation plan:**
    1. AC-9 (fresh-machine simulation): in a scratch dir, set `HOME=/tmp/cmux-fresh`, ensure `~/.sounds/cmux` doesn't exist, run a stripped harness or just the new block; afterwards `readlink -f /tmp/cmux-fresh/.sounds/cmux` resolves into the live `$HOME/dotfiles/cmux`. (Easier: run on the real `$HOME` after first removing `~/.sounds/cmux`; verify symlink correct.)
    2. AC-10 (idempotency): run `installation/symlink.sh` twice; `find $HOME/.sounds -name '*.old*'` empty; `ls -la $HOME/.sounds/` shows exactly one `cmux` entry pointing into the repo.
    3. AC-11a (dangling-link cleanup): `ln -sfn $HOME/dotfiles/cmux/dingding.wav $HOME/.sounds/cmux-notification.wav` then run `installation/symlink.sh`; afterwards `test ! -e $HOME/.sounds/cmux-notification.wav -a ! -L $HOME/.sounds/cmux-notification.wav`.
    4. AC-11b (regular-file safety): `echo test > /tmp/sentinel; ln -sf /tmp/sentinel /tmp/sentinel-link; <move it into ~/.sounds/cmux-notification.wav as a regular file via cp>`; run `symlink.sh`; the regular file is still there.
    5. AC-12: `grep -F __HOME__ $HOME/.config/cmux/settings.json` exits 1; `grep -F "$HOME/.helpers/cmux-random-sound" $HOME/.config/cmux/settings.json` exits 0.
  - **Validates when:** all five checks pass.

- [ ] 5.0 README updates                                                                              ← Serves: AC-14, AC-16
  - [ ] 5.1 Update the `init.sh` description: replace "symlinks `cmux-notification.wav` into `~/.sounds/`" with directory-symlink wording; mention the new helper.
  - [ ] 5.2 Add `cmux-random-sound` row to the `## Helpers (~/.helpers)` table.
  - [ ] 5.3 Replace the single `cmux-notification.wav` third-party notice with a section listing each file under `dotfiles/cmux/` (Title, Author/Source, License). Use the existing entry's structure for `dingding.wav`; add 5 new entries for the issue-supplied clips.
  - [ ] 5.4 Add a short subsection "Adding more cmux sounds" near the helpers section: drop a supported file into `~/.sounds/cmux/` (or `dotfiles/cmux/` to track it in the repo), then reload cmux config with `cmd+shift+,`. Document `CMUX_RANDOM_SOUND_VOLUME` here.
  - **Pre-implementation validation plan:**
    1. `grep -nE '~/\.sounds/cmux/' README.md` returns at least one match (install description).
    2. `grep -nE '\| .cmux-random-sound. \|' README.md` finds the helpers-table row.
    3. `grep -nF 'cmd+shift+,' README.md` finds the reload-config line.
    4. `grep -nF 'CMUX_RANDOM_SOUND_VOLUME' README.md` finds the env-var doc.
    5. `grep -cE '^- \*\*Title:\*\*' README.md` returns >= 6 (one for each of the 6 source clips: `dingding.wav` + 5 new). Actual count may be higher if files are sub-listed; manual inspection on top of the grep.
    6. `grep -F 'cmux-notification.wav' README.md` returns no path-bearing matches outside the rename callout (the rename can be referenced; the live install path should not be).
  - **Validates when:** all six checks pass and visual review confirms third-party block lists each file.

- [ ] 6.0 End-to-end verification, gitignore audit, PR description prep                                ← Serves: AC-13, AC-15
  - [ ] 6.1 `git check-ignore -v dotfiles/helpers/cmux-random-sound dotfiles/cmux/*` — expect zero matches (AC-15).
  - [ ] 6.2 Run `installation/symlink.sh` end-to-end on this machine (post-implementation), then trigger a cmux notification (manual). Observe a sound from `~/.sounds/cmux/` plays. Trigger 5+ in a row; observe rotation. Log which sounds played in evidence section. (AC-13)
  - [ ] 6.3 Run the project's reconciliation audit per rule 13 (phase-gate audit).
  - [ ] 6.4 Build the AC verification table; write paste-ready PR description to `/tmp/ai-dotfiles-pr-description-<timestamp>.md` per rule 12. Include a `pbcopy` command. **Do NOT push, do NOT `gh pr create`** (rule 09).
  - **Pre-implementation validation plan:**
    1. AC-15: `git check-ignore -v dotfiles/helpers/cmux-random-sound` and `git check-ignore -v dotfiles/cmux/*` both emit nothing.
    2. AC-13: cmux notification fired manually plays a random sound; 5 consecutive notifications produce ≥ 2 distinct sounds (recorded in evidence table — manual step, flagged "human verification").
    3. PR description file exists at the expected `/tmp/ai-dotfiles-pr-description-*.md` path; `pbcopy` command supplied.
    4. Phase-gate audit `Result: PASS` (or `PASS WITH WARNINGS` with explicit risks called out).
  - **Validates when:** all four checks pass; the manual cmux trigger is acknowledged by the human as having played varied sounds.

## Notes on commit strategy

Per rule 05 + rule 10:
- One commit per completed parent task; conventional-commits prefix matching the branch type (`feat:`).
- All commits squash-merged in the final PR. Single PR title: `feat: Add Randomized cmux Notification Sounds`.
- No `Co-Authored-By: Claude` (rule 09 + saved memory).
