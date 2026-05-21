# PRD: notifyctl — Cross-Platform DND-Aware Notification Helper

> **STATUS: DRAFT / SKETCH — Gate 1 NOT yet passed.**
>
> This document captures a forward-looking design idea that emerged while
> shipping the macOS Tahoe DND fix for `cmux-random-sound`. It exists so the
> idea is preserved with full context, **not** as a ready-to-implement PRD.
>
> Codebase analysis is incomplete. Linux DND surface is unexplored. Module
> layout decisions are open. Do not generate `tasks-notifyctl.md` from this
> document or begin implementation until the human has reviewed it,
> answered the open questions, and explicitly promoted it to active by
> removing this banner.
>
> The current shippable state is the bash helper in
> `dotfiles/helpers/cmux-random-sound`, which solves the immediate problem
> via the Shortcuts CLI (see the project README "Do Not Disturb / Focus"
> section). `notifyctl` is the *next* problem we'd solve if/when the bash
> approach stops being sufficient.

## Summary

Replace the bash `cmux-random-sound` helper with a small Go CLI binary
(`notifyctl`) that lives in a subdirectory of this dotfiles repo. The
binary plays a random sound from one or more configured directories,
respecting the host OS's Do Not Disturb / Focus state. Cross-platform from
day one: macOS (via direct read of the TCC-gated DND state — possible
because a compiled binary can hold a Full Disk Access grant cleanly, which
a bash script can't), and Linux (via freedesktop notification-inhibition
queries, GNOME first, others later).

The bash helper is fine today on macOS, but Apple's continued churn on
Focus APIs (Monterey → Sequoia → Tahoe each broke the prior detection path)
plus the Shortcuts CLI's ~0.6–0.9s per-invocation latency suggest the
"clever shell trick" approach is structurally brittle. A single binary we
own becomes a stable contract layer between cmux's `notifications.command`
hook and the OS's churning Focus state.

## Why now (motivation, not a commitment to build)

Three pressures are converging:

1. **Cross-machine pressure.** User runs ~5 machines daily; two currently
   use cmux (both Mac). Future cmux installs on the Fedora workstation and
   Hyprland tile-WM box will need a real DND check; bash doesn't have a
   clean cross-platform story for that.
2. **Tahoe pressure.** Apple has TCC-gated the Focus state file, killed
   the `notifyutil` keys we previously relied on, and made the Shortcuts
   CLI the only blessed shell path — and that path needs a manually-created
   per-machine Shortcut and adds ~0.6–0.9s per notification.
3. **FDA structural insight.** A compiled binary can be added to *Privacy &
   Security → Full Disk Access* in System Settings and from then on can
   read `~/Library/DoNotDisturb/DB/Assertions.json` directly. The same
   trick is impossible for a bash script because TCC entitlements attach
   to the executable that's actually running (`/bin/bash`), and granting
   FDA to `/bin/bash` would be wildly over-broad — every shell script on
   the system would inherit it. The Go binary unlocks the FDA path
   cleanly.

None of these is urgent today. None makes the bash helper *wrong*. They
just bound when the bash helper stops being the right answer.

## Codebase Analysis

**INCOMPLETE — gate 1 not passed.** This section lists what would need
to be explored before implementation. Not a checklist for the next session
— a backlog for the human to scope when this gets promoted.

### To explore

- Existing Go code in this repo (`grep -r '\.go$' .` — currently believed
  to be none, but verify before deciding on module layout).
- `dotfiles/helpers/` install pipeline — how a binary (vs. a script) would
  thread through `installation/symlink.sh`. Currently helpers are
  symlinked from a directory; binaries built per-platform may want a
  separate convention.
- `.gitignore` interactions — do we commit the binary, build from source
  during `init.sh`, or both?
- Whether cmux's `notifications.command` field accepts arguments cleanly,
  or whether the binary needs to be a single-arg invocation (current
  helper is). The existing rendered settings has
  `CMUX_RANDOM_SOUND_VOLUME=0.5 /Users/.../cmux-random-sound` which is a
  shell command, so cmux is shelling out — arg parsing should be fine.
- Existing PRDs (`tasks/prd-cmux-random-sounds.md`,
  `tasks/prd-cmux-config.md`) for conventions and prior decisions on
  cmux integration.

### To research (external)

- `~/Library/DoNotDisturb/DB/Assertions.json` exact schema on Tahoe.
  Today's helper can't read it (TCC); a one-shot manual `sudo cat`
  could surface the structure for design.
- GNOME notification-inhibition queries — `gsettings get
  org.gnome.desktop.notifications show-banners` vs. the freedesktop
  `org.freedesktop.Notifications.Inhibited` DBus property. Which is
  authoritative? Which reflects DND vs. "all notifications off"?
- KDE Plasma `org.freedesktop.Notifications` flavor — probably different.
  Out of scope for v1.
- Existing Go libraries: `github.com/caseymrm/menuet` ecosystem,
  `gioui.org/system/desktop`, anything that already wraps the
  freedesktop spec. Don't roll our own DBus client if a library suffices.

### Constraints we already know

- macOS Tahoe Assertions.json is TCC-gated. Requires a one-time human
  action in System Settings to grant FDA to the binary. We need to
  handle "FDA not granted yet" gracefully (fall back to Shortcuts CLI;
  one-time stderr nudge with the grant instructions).
- The current bash helper's contract surface — env vars
  (`CMUX_RANDOM_SOUND_VOLUME`, `CMUX_RANDOM_SOUND_DEBUG`,
  `CMUX_RANDOM_SOUND_IGNORE_DND`) and the config file
  (`~/.config/cmux/random-sound-volume`) — must be preserved for
  back-compat OR migrated with a clear transition path. Don't break
  machines mid-upgrade.
- cmux is invoked as a GUI app on macOS, so it doesn't inherit
  interactive shell `$PATH`. The binary's invocation must be by
  absolute path (the existing helper already is).

## Goals (v1)

- Single Go binary, statically linkable where the OS allows, minimal cgo
  (only if FDA-protected macOS APIs genuinely require it).
- CLI: `notifyctl notify [--config PATH]` plays one random sound,
  respecting DND. Drop-in replacement for `cmux-random-sound`.
- TOML config file (XDG-style location) listing one or many sound
  directories, default playback volume, DND-bypass flag. Per-source
  overrides eventually, but not necessarily v1.
- Platform-aware DND detection with a clean strategy interface
  (`type DNDProbe interface { Active() (bool, error) }`):
  - **macOS:** read Assertions.json directly when FDA is granted; fall
    back to Shortcuts CLI when not.
  - **Linux (GNOME):** query the appropriate DBus / gsettings signal.
  - **Linux (others):** stub returning "unknown" → fail open. Tracked
    as follow-up.
- Back-compat with the existing helper's env-var contract.
- One-shot run latency under 200ms on macOS when FDA is granted (vs.
  ~600–900ms for the bash + Shortcuts path).

## Non-Goals (v1)

- **Building this right now.** This PRD is a sketch.
- Homebrew formula / DNF spec / Nix package — out of scope for v1.
  Distribution is "git clone, `make build`, helper-style symlink" until
  there's demand for prebuilt packages.
- Daemon mode or long-running process — `notifyctl` is invoked per
  notification and exits. If per-invocation latency proves a problem
  even after the FDA path lands, daemon-ize as a follow-up.
- Replacing cmux. `notifyctl` integrates with cmux's hook; doesn't
  replace cmux.
- Custom audio playback engine. Defer to `afplay` (macOS), `paplay` /
  `aplay` / `pw-play` (Linux), pluggable per platform.
- KDE / Hyprland / Sway / niri DND detection — Linux v1 is GNOME-only.
- A GUI. Pure CLI.
- Replacing every shell helper in the repo with `notifyctl` primitives.
  Tempting (`notifyctl say`, `notifyctl banner`), but YAGNI for v1.

## Sketch: CLI Surface

```
notifyctl notify [--config PATH]      # play one random sound, respecting DND
notifyctl status                       # print current DND state + resolved config
notifyctl doctor                       # diagnose FDA grant, shortcut presence, audio backend
notifyctl version
```

Config defaults to `$XDG_CONFIG_HOME/notifyctl/config.toml`, falling back
to `~/.config/notifyctl/config.toml`.

## Sketch: Config File

```toml
[playback]
volume = 0.4                           # 0.0–1.0; >1.0 amplifies but may clip
backend = "auto"                       # "afplay" | "paplay" | "auto"

[[sources]]
path = "~/.sounds/cmux"
recursive = true

[[sources]]
path = "~/.sounds/quiet"               # optional second pool, e.g. for work hours

[focus]
mode = "respect"                       # "respect" | "ignore"
override_env = "CMUX_RANDOM_SOUND_IGNORE_DND"
```

(Final format TBD — TOML vs. YAML, key names, etc. all bikeshed
decisions to lock down at gate 1.)

## macOS DND Detection — the FDA path

The crux of why a binary is worth building.

`~/Library/DoNotDisturb/DB/Assertions.json` is the source of truth for
Focus state on Tahoe. Reading it requires TCC's Full Disk Access. The
binary's flow:

1. Try to `os.Open` the file.
2. On `EPERM` (FDA not yet granted), fall back to invoking
   `shortcuts run cmux-focus-check` — same path as today's bash helper.
   Emit a one-time stderr nudge: *"For faster DND detection, grant
   notifyctl Full Disk Access in System Settings → Privacy & Security."*
   The nudge is rate-limited (e.g. once per 24h) via a marker file in
   `~/.local/state/notifyctl/`.
3. On success with empty `storeAssertionRecords` → DND off, play.
4. On success with non-empty records → DND on, skip.

The fallback chain means the binary works on day 1 without any system
settings change, and just gets faster after the human grants FDA.

## Linux DND Detection — sketch

GNOME (most likely first target — Fedora workstation):

- `gsettings get org.gnome.desktop.notifications show-banners` returns
  `false` when DND is on. Cheap to query.
- Or `busctl --user get-property org.freedesktop.Notifications
  /org/freedesktop/Notifications org.freedesktop.Notifications.Inhibited`
  where the daemon supports the spec extension.

Hyprland / Sway / KDE: v1 returns "unknown" → fail open. Tracked as
follow-ups.

## Open Questions (require human input before gate 1)

1. **Module layout.** New top-level dir (`dotfiles/notifyctl/` with a
   `go.mod`)? Separate Git repo with subtree-merge into this one? The
   answer probably depends on whether `notifyctl` gets a Homebrew formula
   early (separate repo) vs. stays a personal tool (subdirectory).
2. **Name.** `notifyctl` is the working title. Alternatives the human
   floated: variations on "notify CTL". `dndsound`? `cmuxsnd`?
   `focussafe`? Naming bikeshed; locking before code matters.
3. **Linux scope for v1.** Fedora/GNOME only, or also at least stub-test
   on the Hyprland machine?
4. **Migration.** Keep the bash helper alongside `notifyctl` indefinitely
   (graceful, two install paths) or rip it the day `notifyctl` ships?
5. **Build vs. ship binary.** Build from source in `init.sh` (requires
   Go on the target machine) vs. commit prebuilt binaries per platform
   to the repo (bloats the repo with binaries) vs. hybrid (release tarballs)?
6. **Distribution timeline.** When (if ever) does this become a real
   Homebrew/DNF package? Affects #1 above.

## Open Questions (require codebase analysis at gate 1)

1. Exact Assertions.json schema on Tahoe — confirm via a one-shot
   `sudo cat` once we're ready to design the parser.
2. Does `shortcuts run` work reliably under cmux's GUI-launched
   subprocess environment? Today's bash helper uses absolute path —
   binary should too.
3. Is there an existing Go DND library worth adopting? `caseymrm/*`?
   Anything in the wider Go-on-macOS ecosystem? Research before
   rolling our own DBus / IOKit client.

## Follow-up PRDs (post-v1, sketched here only so they don't get lost)

- `notifyctl` Homebrew formula + DNF spec + Nix flake
- KDE / Hyprland / Sway / niri DND detection
- `notifyctl` daemon mode (only if per-invocation latency proves a
  real problem after the FDA path lands)
- Migrating other dotfiles helpers to `notifyctl` primitives —
  `notifyctl say` (TTS), `notifyctl banner` (system notification),
  etc. Pure speculation today; tracked here only so it doesn't get lost.

## Acceptance Criteria

DEFERRED to gate 1. This is a sketch, not a contract. The human will
define acceptance criteria after promoting this PRD to active and
answering the open questions above.

## Codebase Analysis Reviewed

**NO.** Gate 1 NOT passed. See the banner at the top of this document.
