# PRD: cmux Randomized Notification Sounds

## Summary
Replace cmux's single fixed notification sound with a randomized pick from a
local directory of sounds. Use cmux's `notifications.command` hook (the clean
schema-supported seam) to invoke a tiny dotfiles-managed helper that selects
one supported audio file at random and plays it without blocking. The existing
`cmux-notification.wav` stays in the rotation (renamed `dingding.wav`),
joined by five new voice clips supplied by the human via GitHub issue #26.

## Codebase Analysis

### Explored
- `dotfiles/cmux-settings.json` — JSONC template; `notifications.sound = "custom_file"` + `notifications.customSoundFilePath = "__HOME__/.sounds/cmux-notification.wav"`.
- `dotfiles/cmux-notification.wav` — RIFF WAVE, the existing single sound (Envato "Media Help").
- `installation/symlink.sh` — `mkdir -p $HOME/.sounds`, helpers-idiom symlink for the wav, then invokes `generate_cmux_settings.sh`.
- `dotfiles/helpers/generate_cmux_settings.sh` — `__HOME__` → `$HOME` substitution; chmod 600 on output.
- `tasks/prd-cmux-config.md`, `tasks-cmux-config.md` — prior feature this builds on.
- `README.md` — already documents `~/.sounds/`, the helper, and the wav's third-party notice.
- cmux schema (verified live): `notifications.sound` enum includes `"none"`; `notifications.command` is a free-form string. The issue's proposed config is schema-valid.
- `~/Downloads/` — all five issue-attached zips already present and inspected.

### Relevant patterns
- Tracked configs are flat in `dotfiles/dotfiles/`. There is no precedent for shipping a *directory* of asset files; this PRD introduces one.
- Helper scripts live in `dotfiles/helpers/` and are PATH-exposed via `~/.helpers` (symlinked in `symlink.sh`).
- `symlink.sh` has two idioms: file-idiom (always backs up to `*.old$NOW`) and helpers-idiom (`readlink`-checked, idempotent). The wav uses helpers-idiom.

### Constraints discovered
- `~/.local/bin/` is not in the install pipeline at all; using `~/.helpers/` avoids introducing a new install destination (decision Q3=A).
- macOS-only `afplay`. cmux is darwin-only on this user's machine; helper should fail-soft on Linux rather than error.
- The new sound assets are Envato-Elements-licensed (filename pattern matches). Per saved memory the user accepts publishing licensed Envato wavs in this public repo; per-file third-party notices will be added.
- cmux schema does not document how `notifications.command` is invoked (env, args, cwd, timeout). The helper must be self-sufficient and quick-returning.
- `notifications.command` runs synchronously from cmux's perspective unless backgrounded; the helper must launch `afplay` detached so the script returns fast.

### Decisions (confirmed by human via lettered Q&A)
- **Q1=B:** directory name is `cmux/` (repo: `dotfiles/cmux/`; install path: `~/.sounds/cmux/`).
- **Q2=B:** ship both .wav and .mp3 variants of "Man Asking For Help" (8 files for that pack).
- **Q3=A:** helper lives at `dotfiles/helpers/cmux-random-sound`, invoked as `__HOME__/.helpers/cmux-random-sound` from settings.
- **Q4=A:** the existing `cmux-notification.wav` moves into the new directory as `dingding.wav`; the now-dangling old `~/.sounds/cmux-notification.wav` symlink is cleaned up by `symlink.sh` if present.
- **Q5=A:** filenames inside the directory normalized to short kebab-case.

### Codebase Analysis Reviewed
The codebase analysis above was reviewed and confirmed by the human in the
clarifying-questions exchange before this PRD was written. Gate 1 passed.

## Background
cmux's notification sound is currently a single fixed file. The human wants
variety per notification. cmux has no native list/array support for custom
sounds, but it does expose a `notifications.command` hook that fires alongside
notification delivery. This is the correct seam — far simpler than file-system
interposition (FUSE, ptrace) and well within the tool's documented contract.

The dotfiles repo already manages the cmux settings template, a generated
settings file, and a single wav. This PRD generalizes the single wav to a
directory and introduces one new helper script that reads from that directory.

## Goals
- One random supported sound plays per cmux notification.
- The existing sound (now `dingding.wav`) remains in rotation.
- Adding or removing sounds is a drop-in operation: edit `dotfiles/cmux/`, re-run install (or just drop a file into `~/.sounds/cmux/` since it's a directory symlink).
- Re-running `installation/symlink.sh` is idempotent — no new `*.old<digits>` backups for the cmux entries.
- Existing machines transition cleanly: the dangling `~/.sounds/cmux-notification.wav` symlink from the prior install is removed.

## Non-Goals
- Linux notification-sound support (cmux is darwin-only on this machine).
- Bidirectional sync between cmux's settings GUI and the dotfiles template (existing GUI-drift behavior is unchanged).
- Volume normalization, fade-in/out, or any audio processing of the sound files.
- A Makefile or rule-07 command surface remediation — tracked separately from this feature.
- Making the helper script configurable via env vars or flags (KISS: hardcoded directory path).

## Architecture & Approach

### Files added (in repo)
- `dotfiles/cmux/` — new directory containing all notification sounds. Contents:
  - `dingding.wav` — the existing Envato "Media Help" wav (moved + renamed from `dotfiles/cmux-notification.wav`).
  - `british-detective-can-i-ask-you-something.wav`
  - `british-male-what-do-you-think.wav`
  - `english-warrior-can-you-help-me.wav`
  - `wizard-i-am-ready-and-waiting.wav`
  - `man-asking-for-help-1.wav`, `man-asking-for-help-2.wav`, `man-asking-for-help-3.wav`, `man-asking-for-help-4.wav`
  - `man-asking-for-help-1.mp3`, `man-asking-for-help-2.mp3`, `man-asking-for-help-3.mp3`, `man-asking-for-help-4.mp3`
  - 13 audio files total. (`__MACOSX/` and `.DS_Store` cruft from the zip are excluded.)
- `dotfiles/helpers/cmux-random-sound` — bash script:
  1. `set -euo pipefail`.
  2. `sound_dir="$HOME/.sounds/cmux"` (hardcoded; matches install path).
  3. `find` files matching `*.aiff *.aif *.wav *.mp3 *.m4a` (case-insensitive).
  4. Pick one at random via `awk 'BEGIN{srand()} {a[NR]=$0} END{if (NR) print a[int(rand()*NR)+1]}'`.
  5. Exit 0 silently if directory missing or empty (no sound to play).
  6. Exit 0 silently on non-darwin (no `afplay`).
  7. Read optional env var `CMUX_RANDOM_SOUND_VOLUME` (float passed as `afplay -v`); when unset, no `-v` flag is passed (system default).
  8. Launch `afplay [-v $vol] "$sound" >/dev/null 2>&1 &` and return immediately.

### Files modified
- `dotfiles/cmux-settings.json` — replace the `notifications` block:
  - `"sound": "none"`
  - `"command": "__HOME__/.helpers/cmux-random-sound"`
  - Remove `"customSoundFilePath"`.
- `installation/symlink.sh` — replace the existing wav-symlink block with:
  1. `mkdir -p $HOME/.sounds` (still needed for the parent dir).
  2. Helpers-idiom symlink: `~/.sounds/cmux` → `$HOME/dotfiles/cmux/` (the whole directory).
  3. One-time cleanup: if `~/.sounds/cmux-notification.wav` exists as a symlink pointing into the repo, remove it (so existing machines don't keep a dangling link). Be conservative — only remove if it's a symlink and resolves into `$HOME/dotfiles/`; never touch a regular file.
  4. Continue invoking `generate_cmux_settings.sh` (unchanged).
- `dotfiles/cmux-notification.wav` — **deleted from repo** (moved into the new directory).
- `README.md` —
  - Update `init.sh` description: replace "symlinks `cmux-notification.wav` into `~/.sounds/`" with "symlinks the `cmux/` sound directory into `~/.sounds/cmux/`" and mention the random-sound helper.
  - Add `cmux-random-sound` to the helpers table.
  - Replace the single `cmux-notification.wav` third-party notice with an entry per file under `dotfiles/cmux/` (or one consolidated section listing each).
  - Mention "drop a sound into `~/.sounds/cmux/` and reload cmux config (`cmd+shift+,`) to pick it up" — satisfies the issue's "how to reload cmux config" requirement.

### Files NOT modified
- `dotfiles/helpers/generate_cmux_settings.sh` — template substitution still works as-is (`__HOME__` → `$HOME`); no logic change needed.
- `dotfiles/.profile` — generator wiring unchanged.

### On-disk layout after install
| Path | Type | Backed by |
|---|---|---|
| `~/.config/cmux/settings.json` | regular file (rendered) | `dotfiles/cmux-settings.json` template |
| `~/.sounds/cmux/` | symlink to directory | `$HOME/dotfiles/cmux/` |
| `~/.sounds/cmux-notification.wav` | **gone** (cleaned up if present) | (n/a) |
| `~/.helpers/cmux-random-sound` | symlink (via `~/.helpers` dir) | `$HOME/dotfiles/helpers/cmux-random-sound` |

### Why these design choices
- **Directory symlink, not a per-file symlink loop:** lets the human drop a file into `~/.sounds/cmux/` (or the repo) and have it picked up immediately, without re-running `symlink.sh`.
- **Helper under `dotfiles/helpers/`, not `~/.local/bin/`:** uses an install destination already wired up; no PATH or executable-bit logic to add.
- **Background `afplay`:** cmux's `notifications.command` contract isn't documented, so detaching is the safe default — guarantees we don't block notification delivery.
- **Hardcoded `$HOME/.sounds/cmux` in the helper:** matches the install path; keeping it un-parameterized keeps the script ~10 lines and avoids needing a generator step for the helper itself.
- **One-time cleanup of the old symlink:** avoids leaving a broken `~/.sounds/cmux-notification.wav` on machines that already ran the prior install; the cleanup is conditional and conservative (symlink-only, into-repo-only).

## Acceptance Criteria

- [ ] **AC-1:** `dotfiles/cmux-settings.json` parses cleanly (JSONC strip + `jq`) and its `notifications` block contains exactly `"sound": "none"` and `"command": "__HOME__/.helpers/cmux-random-sound"`, with no `"customSoundFilePath"` key.
- [ ] **AC-2:** `dotfiles/cmux/` exists in the repo and contains exactly these 13 files (no `__MACOSX/`, no `.DS_Store`):
  - `dingding.wav`, `british-detective-can-i-ask-you-something.wav`, `british-male-what-do-you-think.wav`, `english-warrior-can-you-help-me.wav`, `wizard-i-am-ready-and-waiting.wav`
  - `man-asking-for-help-{1,2,3,4}.wav`
  - `man-asking-for-help-{1,2,3,4}.mp3`
- [ ] **AC-3:** `dingding.wav` is byte-for-byte identical to the prior `dotfiles/cmux-notification.wav` (`cmp` returns 0 against the old git blob).
- [ ] **AC-4:** `dotfiles/cmux-notification.wav` no longer exists in the repo.
- [ ] **AC-5:** `dotfiles/helpers/cmux-random-sound` exists, is executable (`-rwxr-xr-x` or stricter), passes `bash -n` parse, and `shellcheck` reports no errors (warnings are tolerated; documented if any).
- [ ] **AC-6:** Running the helper with the install-path directory empty or missing exits 0 with no stderr output (verified by removing `~/.sounds/cmux/` temporarily and running the helper).
- [ ] **AC-7:** Running the helper with the install-path directory populated exits 0 in **<500ms wall-clock** and an `afplay` process is observable in `ps -ef` immediately after. (Original draft was `<100ms`; revised after measurement showed `bash` interpreter startup alone is ~146ms on this machine, so the prior threshold was unachievable. Confirmed by human in this session. The `<500ms` value captures the real intent — "does not block cmux notification handling" — without over-specifying.)
- [ ] **AC-8:** Running the helper N=20 times against the populated directory plays each file at least once with high probability (manually: observe the picked filename via a one-shot `set -x` debug run; or scripted: capture the chosen filename to stdout in a debug variant and check distribution).
- [ ] **AC-9:** Running `installation/symlink.sh` on a machine where `~/.sounds/cmux/` does not exist creates a symlink at `~/.sounds/cmux` whose `readlink -f` resolves to `$HOME/dotfiles/cmux`.
- [ ] **AC-10:** Running `installation/symlink.sh` twice in a row produces zero new `*.old<digits>` files for any cmux-related entry.
- [ ] **AC-11:** If a symlink at `~/.sounds/cmux-notification.wav` exists pointing into `$HOME/dotfiles/`, running `symlink.sh` removes it. If a regular file (not a symlink) exists at that path, `symlink.sh` does NOT touch it (defensive — no accidental data loss).
- [ ] **AC-12:** After `installation/symlink.sh` runs, the generated `~/.config/cmux/settings.json` has `notifications.command` resolved to the absolute path `<HOME>/.helpers/cmux-random-sound` (no `__HOME__` left).
- [ ] **AC-13:** Manual: triggering a cmux notification plays one of the sounds from `~/.sounds/cmux/`. Triggering several notifications in a row plays a mix of different sounds (not always the same one).
- [ ] **AC-14:** `README.md` documents (a) the new helper script in the helpers table, (b) the `~/.sounds/cmux/` install location and how to add a sound, (c) how to reload cmux config so newly-edited settings take effect, and (d) third-party / license attribution for each new sound file.
- [ ] **AC-15:** `git check-ignore -v` against each new file under `dotfiles/cmux/` and `dotfiles/helpers/cmux-random-sound` emits nothing (no accidental capture by `*secret*` or other globs).
- [ ] **AC-16:** `dotfiles/helpers/cmux-random-sound` honors `CMUX_RANDOM_SOUND_VOLUME` (a float passed as `afplay -v`). When unset, no `-v` flag is passed (system default volume). README documents the env var and a recommended value range. Verified by:
  - running `CMUX_RANDOM_SOUND_VOLUME=0.5 dotfiles/helpers/cmux-random-sound` and confirming `afplay -v 0.5 ...` appears in `ps`,
  - and running it without the env var and confirming no `-v` flag appears.

## Non-Goals (additions)
- Per-file loudness normalization (LUFS targeting via `ffmpeg loudnorm`). Tracked as potential follow-up if perceived loudness drift across the source files becomes annoying.

## Open Questions
None — all clarifying questions resolved before this PRD was written.
