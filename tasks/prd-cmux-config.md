# PRD: cmux Config + Custom Notification Sound

## Summary
Bring the cmux terminal's settings file (`~/.config/cmux/settings.json`) and a
custom notification sound (`help.wav`) under dotfiles management so they install
reproducibly via `init.sh` / `run.sh` on a fresh machine. The committed
settings file is a JSONC template with `$HOME` tokenized; a generator helper
renders the real file at install time. The wav ships in the repo and is
symlinked to a dedicated, OS-agnostic location.

## Codebase Analysis

### Explored
- `init.sh` / `run.sh` — top-level bootstrap; both call `installation/symlink.sh`.
- `installation/symlink.sh` — the single point of `$HOME` symlink creation.
- `installation/include/vars.sh`, `lib.sh` — env vars and shell helpers.
- `dotfiles/dotfiles/` — flat directory of tracked configs (no nested `.config/` mirror).
- `dotfiles/helpers/generate_gitconfig.sh` — precedent for a *generated* (not symlinked) config rendered via heredoc.
- `dotfiles/.profile` (lines 148–159) — sources `~/.helpers/util.sh` and `~/.helpers/generate_gitconfig.sh` on every shell startup.
- `~/.config/cmux/settings.json` — exists, mode `0600`, 1 link (regular file). Contents are the commented-out template; user will enable `notifications.customSoundFilePath`.
- `~/Downloads/help.wav` — RIFF WAVE, 16-bit stereo 44.1 kHz, 528 KB.

### Relevant patterns
- Tracked configs in `dotfiles/dotfiles/` are **flat** (e.g. `.zshrc`, `gpg.conf`, `Afterglow.itermcolors`).
- `installation/symlink.sh` has two idioms: a **file idiom** (always backs up to `*.old$NOW`) and a **helpers idiom** (`readlink`-checked, idempotent).
- `generate_gitconfig.sh` writes a real file into `$HOME`, prepends a "generated, edit the template" header, and is invoked from `.profile` on every shell startup.

### Constraints discovered
- **No Makefile**. Per rule 07 the gap is acknowledged; not remedied as part of this feature.
- `~/.config/cmux/` parent dir does not exist on a fresh machine; install must `mkdir -p`.
- `.gitignore` has a `*secret*` glob — defensive `git check-ignore` confirms the new files aren't caught.
- The committed settings file cannot be a plain symlink because cmux needs an absolute path in `customSoundFilePath` and that path depends on `$HOME`. Rendering at install time is required.

### Decisions (confirmed)
- **Repo layout:** flat — `dotfiles/dotfiles/cmux-settings.json` and `dotfiles/dotfiles/cmux-notification.wav`.
- **Sound install path:** `~/.sounds/cmux-notification.wav` (dedicated dir; not co-located with cmux state, not mixed with executables in `~/.helpers`).
- **Path portability:** template the path via a `__HOME__` placeholder, rendered by a generator helper.
- **Source disposition:** copy (not move) from `~/Downloads/help.wav`; original stays put.
- **Filename in repo:** renamed to `cmux-notification.wav` for clarity.
- **Symlink idiom:** helpers idiom (`readlink`-checked, idempotent) — no `*.old$NOW` files on re-run.

## Background
cmux's settings live in `~/.config/cmux/settings.json` (with an Application
Support fallback). Today this file is a one-link regular file on this machine
only — losing or rebuilding the machine loses the configuration. The custom
notification sound (`help.wav`) lives in `~/Downloads/`, which is a
non-canonical location that gets purged on most users' machines.

This feature mirrors how the rest of the repo treats shell, git, and SSH
configs: track them in `dotfiles/dotfiles/`, install them via
`installation/symlink.sh`. The wrinkle is that `customSoundFilePath` requires
an absolute path with `$HOME` baked in, which forces a generated-file pattern
instead of a pure symlink (matching the existing `generate_gitconfig.sh`
precedent).

## Goals
- `~/.config/cmux/settings.json` ends up with the repo's settings on every
  fresh machine after running `init.sh`.
- `cmux-notification.wav` ships with the repo and lands at a stable,
  predictable path that doesn't depend on the user's name.
- The committed settings file references the sound via a tokenized path, not
  hardcoded `/Users/portaj/...`.
- Re-running `symlink.sh` is idempotent for the new entries.

## Non-Goals
- Mirroring the rest of `~/.config/` — only cmux this round.
- Auto-syncing edits made via cmux's settings GUI back into the repo.
- Introducing a Makefile (rule-07 deviation tracked separately).
- Linux support — cmux is currently a darwin-only app on this machine; the
  install steps will run on Linux but cmux won't be there to read them.
- Bidirectional sync with the Application Support fallback location.

## Architecture & Approach

### Files added (in repo)
- `dotfiles/dotfiles/cmux-settings.json` — JSONC. Starts from the existing
  commented-out template; uncomments **only** the
  `notifications.customSoundFilePath` key (and any sibling key cmux requires to
  actually pick up the custom sound — see Open Questions). The path value is
  the literal string `__HOME__/.sounds/cmux-notification.wav`.
- `dotfiles/dotfiles/cmux-notification.wav` — byte-for-byte copy of
  `~/Downloads/help.wav` at the time of commit.
- `dotfiles/helpers/generate_cmux_settings.sh` — executable script that:
  1. reads `$HOME/dotfiles/cmux-settings.json`,
  2. substitutes every occurrence of `__HOME__` with `$HOME`,
  3. prepends a "this file was generated, edit the source" header comment,
  4. writes the result to `$HOME/.config/cmux/settings.json`,
  5. is safe to re-run (overwrites unconditionally; matches `generate_gitconfig.sh`).

### Files modified
- `installation/symlink.sh` — append a single new block that:
  1. `mkdir -p $HOME/.sounds $HOME/.config/cmux`
  2. creates `$HOME/.sounds/cmux-notification.wav` symlink (helpers idiom),
  3. invokes `$HOME/dotfiles/helpers/generate_cmux_settings.sh` to render the
     settings file.
- `README.md` — `## Helpers` table gets a row for `generate_cmux_settings.sh`;
  the `init.sh` description mentions cmux settings + `~/.sounds/`.

### Files NOT modified
- `dotfiles/.profile` — generator runs from `symlink.sh`, not on every shell
  startup. (See Open Question 1.)

### On-disk layout after install
| Path | Type | Backed by |
|---|---|---|
| `~/.config/cmux/settings.json` | regular file (rendered) | `dotfiles/dotfiles/cmux-settings.json` template |
| `~/.sounds/cmux-notification.wav` | symlink | `$HOME/dotfiles/cmux-notification.wav` |
| `~/Downloads/help.wav` | unchanged | (untouched) |

### Why these design choices
- **`~/.sounds/` not `~/.helpers/sounds/`:** `~/.helpers` is a symlink to the
  repo's executables-on-PATH directory; mixing binary assets in there blurs
  its purpose. `~/.sounds/` is dedicated, OS-agnostic, and creates no
  namespace pollution.
- **Generated file (not symlink) for settings.json:** the template contains a
  `__HOME__` placeholder that must be substituted to a real path before cmux
  reads it. Substitution requires a real file. Matches the
  `generate_gitconfig.sh` precedent.
- **Helpers idiom on the wav symlink:** prevents spurious `*.old$NOW` files on
  every re-run of `symlink.sh`.

## Acceptance Criteria

- [ ] **AC-1:** `dotfiles/dotfiles/cmux-settings.json` exists in the repo,
  parses cleanly when comments are stripped (e.g. `jq` after a JSONC strip
  pass), and contains the literal string
  `__HOME__/.sounds/cmux-notification.wav` as the value of
  `notifications.customSoundFilePath`.
- [ ] **AC-2:** `dotfiles/dotfiles/cmux-notification.wav` exists, is reported
  by `file(1)` as `RIFF (little-endian) data, WAVE audio`, and is byte-for-byte
  identical to `~/Downloads/help.wav` at commit time
  (`cmp` returns 0).
- [ ] **AC-3:** `dotfiles/helpers/generate_cmux_settings.sh` exists, has
  executable mode bits, and produces a `~/.config/cmux/settings.json` whose
  content is the template with **every** `__HOME__` replaced by the runtime
  `$HOME`, plus a leading "generated, do not edit" header comment.
- [ ] **AC-4:** Running `installation/symlink.sh` on a machine where
  `~/.sounds/` does not exist creates the directory and a symlink at
  `~/.sounds/cmux-notification.wav` whose `readlink -f` resolves to
  `$HOME/dotfiles/cmux-notification.wav`.
- [ ] **AC-5:** Running `installation/symlink.sh` twice in a row produces zero
  new `*.old<digits>` files for either the cmux settings or the sound symlink.
- [ ] **AC-6:** After `installation/symlink.sh` runs, opening cmux loads the
  rendered settings without parse errors and plays
  `~/.sounds/cmux-notification.wav` for notifications. (Manual: human triggers
  a notification.)
- [ ] **AC-7:** `~/Downloads/help.wav` is unchanged after running
  `symlink.sh` (`stat` size + mtime unchanged; `cmp` against the repo copy
  returns 0).
- [ ] **AC-8:** `git check-ignore -v` against each new file emits nothing
  (no accidental capture by `*secret*` or other globs).
- [ ] **AC-9:** `README.md` documents the new helper script and the
  `~/.sounds/` install destination in the appropriate sections.

## Open Questions
1. **Generator wiring:** invoke from `symlink.sh` only (current proposal,
   re-render only at install/setup time), or also source from `.profile` like
   `generate_gitconfig.sh` does (re-render on every shell startup, more
   aggressive overwrite of GUI-side edits)?
2. **Companion key:** does cmux require `notifications.sound` to be set to a
   specific value (e.g. `"default"` vs a sentinel) for `customSoundFilePath`
   to actually take effect, or is `customSoundFilePath` alone sufficient? If
   the former, the template should uncomment that key too. (Verify against
   the schema URL in the file header during implementation.)
3. **GUI drift:** if the user later edits via cmux's settings UI, the next
   `symlink.sh` run silently overwrites those edits. Acceptable for v1?
   Should we at least print a `diff` warning when overwrite would happen?
4. **Schema validation:** should `generate_cmux_settings.sh` validate the
   rendered output against the `$schema` URL (or just confirm it's valid
   JSONC) before writing?

## Codebase Analysis Reviewed
The codebase analysis above was reviewed and confirmed by the human as
accurate before this PRD was generated. Gate 1 passed.
