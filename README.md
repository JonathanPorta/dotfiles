# dotfiles

My configuration files for some of my tools.

## Supported Platforms

- **macOS** (Apple Silicon and Intel)
- **Fedora Linux**

## Quick Start

**1. Bootstrap SSH on a fresh machine:**
```bash
# Interactive (confirms detected values before proceeding):
curl -fsSL https://raw.githubusercontent.com/JonathanPorta/dotfiles/master/hello-world.sh | bash

# Headless (skips confirmation, uses defaults):
curl -fsSL https://raw.githubusercontent.com/JonathanPorta/dotfiles/master/hello-world.sh | HEADLESS=true bash
```

**2. Add the generated key to GitHub:**
```bash
cat ~/.ssh/id_ed25519.pub
# Copy output → GitHub → Settings → SSH and GPG keys → New SSH key
```

**3. Install dotfiles and dev tools:**
```bash
# Interactive:
curl -fsSL https://raw.githubusercontent.com/JonathanPorta/dotfiles/master/init.sh | bash

# Headless:
curl -fsSL https://raw.githubusercontent.com/JonathanPorta/dotfiles/master/init.sh | HEADLESS=true bash
```

**4. Restart your shell, then finish setup:**
```bash
zsh -lc "$HOME/devel/$USER/dotfiles/run.sh"
```

## Configuration

All bootstrap scripts detect the local username, home directory, and GitHub username automatically. Before running, they display the detected values and ask for confirmation:

```
Setting up this machine using:
  Local Username: portaj
  Github Username: JonathanPorta
  Home Directory: /Users/portaj
  SSH Directory: /Users/portaj/.ssh

Do these values look correct? [Y/n]:
```

Override any value by setting environment variables:

```bash
GH_USERNAME=myghuser ./hello-world.sh
USER=deploy HOME=/srv/deploy ./init.sh
```

For unattended/CI usage, skip the confirmation prompt entirely:

```bash
HEADLESS=true ./init.sh
# or
./init.sh --headless
```

---

## Scripts

### `hello-world.sh` — Bootstrap SSH

| | |
|---|---|
| **Purpose** | First-run setup for a brand-new machine. Generates an ed25519 SSH key pair, syncs your GitHub public keys into `authorized_keys`, and enables `sshd`. |
| **Idempotency** | **Safe to re-run.** Skips key generation if `~/.ssh/id_ed25519` already exists. Overwrites `authorized_keys` with the latest keys from GitHub on every run (intentional — keeps keys in sync). |
| **Destructive?** | Truncates `~/.ssh/authorized_keys` each run. |

```bash
./hello-world.sh            # interactive
./hello-world.sh --headless # unattended
./hello-world.sh --help     # usage info
```

---

### `init.sh` — Clone Repo & Symlink Dotfiles

| | |
|---|---|
| **Purpose** | Clones this repo (via HTTPS), symlinks shell configs (`.zshrc`, `.zshenv`, `.zprofile`, `.gitignore_global`, `.chruby`, `.helpers`) into `$HOME`, directory-symlinks `dotfiles/cmux/` (the cmux notification-sound pool) into `~/.sounds/cmux/` and renders `~/.config/cmux/settings.json` from the JSONC template (which delegates per-notification sound playback to the `cmux-random-sound` helper, a symlink to the shared `agent-random-sound` engine), installs `jq` and `zsh` if missing, and syncs GitHub `authorized_keys`. |
| **Idempotency** | **Mostly safe to re-run.** If the repo already exists it does a `git fetch` instead of cloning. Existing dotfiles in `$HOME` are renamed to `*.old<timestamp>` before re-linking, so nothing is silently lost. |
| **Destructive?** | Moves existing `.zshrc`, `.zshenv`, `.zprofile`, `.gitignore_global`, `.chruby` to timestamped backups. Truncates `authorized_keys`. **Overwrites `~/.config/cmux/settings.json`** from the tracked template — edit `dotfiles/cmux-settings.json`, not the rendered file. |

```bash
./init.sh            # interactive
./init.sh --headless # unattended
./init.sh --help     # usage info
```

After `init.sh` completes, restart your shell and run `run.sh` (see below).

---

### `run.sh` — Install Dev Tools

| | |
|---|---|
| **Purpose** | Installs applications and dev tools: oh-my-zsh + plugins, vim, gpg, git-lfs, gh CLI, ruby, python, node, and more via Homebrew (macOS) or dnf (Fedora). Re-runs symlinks first. |
| **Idempotency** | **Safe to re-run.** Package managers skip already-installed packages. Oh-my-zsh warns (but does not fail) if already present. |
| **Destructive?** | Re-runs `symlink.sh` (same backup behavior as `init.sh`). |

```bash
zsh -lc "$HOME/devel/$USER/dotfiles/run.sh"
```

> **Note:** `run.sh` expects to run under `zsh` with a login shell so that the full environment (Homebrew PATH, etc.) is available.

---

## Helpers (`~/.helpers`)

The `dotfiles/helpers/` directory is symlinked to `~/.helpers` and added to `$PATH`. This gives you executable helper scripts available as commands from any directory.

| Script | Description |
|---|---|
| `newrepo` | Creates a new local+GitHub repo with ai-rules subtree pre-installed. Interactive prompts for name, location, and visibility. |
| `generate_gitconfig.sh` | Generates `~/.gitconfig` from a template (sourced automatically by `.profile` on shell startup). |
| `generate_cmux_settings.sh` | Renders `~/.config/cmux/settings.json` from `dotfiles/cmux-settings.json`, substituting `__HOME__` with `$HOME`. Invoked from `installation/symlink.sh`. **Note:** edits made via cmux's settings UI are overwritten on the next `init.sh` / `run.sh` run — edit the template, not the rendered file. |
| `agent-random-sound` | Random-sound **engine**: picks a random audio file from a per-app sound pool and plays it in the background (`afplay` on macOS; `ffplay`/`paplay`/`mpv` on Linux). It's invoked through app-named symlinks — `cmux-random-sound` (cmux's `notifications.command` hook) and `herdr-random-sound` (see [Herdr support](#herdr-support)) — and the **invoked name** selects the sound dir (`~/.sounds/<app>/`, falling back to `~/.sounds/cmux/` for non-cmux apps), the volume file (`~/.config/<app>/random-sound-volume`), and the env-var prefix (`<APP>_RANDOM_SOUND_*`, e.g. `CMUX_RANDOM_SOUND_VOLUME`; a generic `AGENT_RANDOM_SOUND_*` is honored as a fallback). Volume precedence: env var > volume file > `0.4` default (loudness-normalized clips don't jumpscare). Set `<APP>_RANDOM_SOUND_DEBUG=1` to print the picked file to stderr. Skips playback while any macOS Focus / Do Not Disturb mode is active (probed via a shared user-created Shortcut — see the "Do Not Disturb / Focus" section below); set `<APP>_RANDOM_SOUND_IGNORE_DND=1` to override. Exits silently if the directory is missing/empty or no player is available. |
| `cmux-random-sound`, `herdr-random-sound`, `claude-random-sound`, `codex-random-sound`, `gemini-random-sound` | Symlinks to `agent-random-sound` (above). The name they're called by is what selects per-app behavior (sound dir, volume file, `<APP>_RANDOM_SOUND_*` env prefix), so the cmux config keeps calling `cmux-random-sound` unchanged. The `claude`/`codex`/`gemini` ones are for wiring sounds straight into those agent CLIs' own hooks — see [Agent CLI hooks](#agent-cli-hooks-claude-code-codex-gemini). |
| `util.sh` | Shell utility functions like `externaldns` and `curlr` (sourced automatically by `.profile`). |

### Adding more cmux notification sounds

The cmux notification sound is randomized per-notification — one file is picked at random from `~/.sounds/cmux/` each time (the helper recurses into subdirectories, so nested layouts are fine). To add a new sound:

1. Drop a `.wav`, `.mp3`, `.aiff`, `.aif`, or `.m4a` file into `~/.sounds/cmux/` (or into `dotfiles/cmux/` if you want it tracked in the public repo — the install symlinks the whole directory).
2. **For personal/sensitive recordings you don't want in the public repo** (e.g. voice notes from family / friends), drop them into `dotfiles/cmux/local/` instead. That subdirectory is gitignored, so files there never land on GitHub but still get scanned by the helper. Naming alone does not protect against voice-cloning attacks — never publish samples of someone's actual voice to a public repo.
3. No reload needed for new sound files — the helper re-scans the directory on every notification, so the next ding picks them up automatically. Reload cmux config (`cmd+shift+,`) only if you've also edited `dotfiles/cmux-settings.json`.

All sounds in `dotfiles/cmux/` are loudness-normalized to **-16 LUFS** (EBU R128) so no single clip is dramatically louder than the others. Playback volume defaults to `0.4` (40% of system volume) — quiet enough not to be a jumpscare, loud enough to notice. To override the default, the helper checks two sources in order:

1. **`$CMUX_RANDOM_SOUND_VOLUME`** environment variable. Easy from a shell — but **only effective if cmux inherits a shell environment.** If cmux is launched as a normal macOS GUI app (Dock, Spotlight, Finder), it will not source `.zshrc` and the env var won't be visible to the helper. If you launch cmux from a terminal, this works.
2. **`~/.config/cmux/random-sound-volume`** — a tiny single-line file with the float value. Works regardless of how cmux was launched. Recommended path for GUI users. *Intentionally user-managed and not seeded by `installation/symlink.sh` — create it yourself when you want it.*

```bash
# Option 1: env var (shell-launched cmux)
export CMUX_RANDOM_SOUND_VOLUME=1.0   # full system volume
export CMUX_RANDOM_SOUND_VOLUME=0.2   # quieter than the default

# Option 2: config file (works with GUI-launched cmux too)
mkdir -p ~/.config/cmux && echo 0.6 > ~/.config/cmux/random-sound-volume
```

Useful range `0.0`–`1.0`; values above `1.0` amplify but may clip. To verify which sound is being picked, set `CMUX_RANDOM_SOUND_DEBUG=1` and run the helper directly — the picked file path is printed to stderr.

### Herdr support

The same random-sound engine works with [Herdr](https://herdr.dev) — the terminal agent multiplexer — through the `herdr-random-sound` symlink. Two things differ from cmux:

- **Herdr has no `notifications.command` hook.** cmux runs an arbitrary command per notification; Herdr instead plays *fixed* files via its `[ui.sound]` config (`done_path` / `request_path`), which can't randomize. To get randomized sounds you invoke `herdr-random-sound` from a hook that fires on the moments you'd want a ding — agent **done** and **needs-input / blocked**.
- **Sound pool.** `herdr-random-sound` reads `~/.sounds/herdr/` and falls back to the shared `~/.sounds/cmux/` pool if you haven't created a herdr-specific one, so it works out of the box. Drop files into `~/.sounds/herdr/` to give Herdr its own set. Volume, DND, and env overrides all follow the `HERDR_RANDOM_SOUND_*` prefix (see the helpers table).

**Wiring (best-effort — verify against your installed Herdr build):**

1. **Silence Herdr's built-in sound** so you don't get a double ding. In Herdr's config (TOML):
   ```toml
   [ui.sound]
   enabled = false
   ```
2. **Fire the helper on the notify-worthy events.** Herdr installs state-report hooks into your agent via `herdr integration`; for Claude Code those ride on its native `Stop` (done) and `Notification` (needs input) hooks. Add a hook that calls the helper — e.g. in Claude Code's `settings.json`:
   ```json
   {
     "hooks": {
       "Stop":         [{ "hooks": [{ "type": "command", "command": "$HOME/.helpers/herdr-random-sound" }] }],
       "Notification": [{ "hooks": [{ "type": "command", "command": "$HOME/.helpers/herdr-random-sound" }] }]
     }
   }
   ```
   If you'd rather hang it off a Herdr-managed hook directly, keep that hook's existing socket `report_agent` call intact and add the helper alongside it — and note Herdr may overwrite shell-style hooks on a `herdr integration` reinstall, so a hook you own separately is the safer place.

> This wiring is an initial pass. The exact hook event names / config path should be confirmed on a live Herdr install — the engine and symlink are solid; the glue is what we'll iterate on.

### Agent CLI hooks (Claude Code, Codex, Gemini)

You don't need a terminal multiplexer in the loop at all — the major agent CLIs each have a native **lifecycle hooks** system that can run a shell command when the agent finishes a turn or needs your input. Point those hooks at the matching `*-random-sound` symlink and you get the same randomized, DND-aware, loudness-normalized sounds straight from the CLI.

Each tool reads its own pool (`~/.sounds/claude/`, `~/.sounds/codex/`, `~/.sounds/gemini/`) and **falls back to the shared `~/.sounds/cmux/` pool** if you haven't made a tool-specific one, so all of these work immediately. Per-tool volume/DND/env follow the `CLAUDE_`/`CODEX_`/`GEMINI_` `_RANDOM_SOUND_*` prefixes (see the helpers table). In every snippet below, `$HOME` expands because the command runs through a shell.

> **Latency note:** the macOS Focus/DND probe adds ~0.6–0.9s per invocation (the sound itself is backgrounded). For a hook the CLI waits on at the end of *every* turn, that's noticeable. If you don't need DND-silencing for a given tool, set its `<TOOL>_RANDOM_SOUND_IGNORE_DND=1` to skip the probe and return instantly.

#### Claude Code — `~/.claude/settings.json`

`Stop` fires when Claude finishes a turn; `Notification` fires when it needs input (`idle_prompt`) or permission (`permission_prompt`). `Stop` takes no `matcher`; use `""` on `Notification` to fire on all notification types.

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [{ "type": "command", "command": "$HOME/.helpers/claude-random-sound" }] }
    ],
    "Notification": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.helpers/claude-random-sound" }] }
    ]
  }
}
```

#### Codex — `~/.codex/config.toml`

`Stop` fires right before Codex ends its turn; `PermissionRequest` fires when it needs approval. (Hooks require a reasonably recent Codex — the system stabilized in 2026.)

```toml
[[hooks.Stop]]
[[hooks.Stop.hooks]]
type = "command"
command = '"$HOME/.helpers/codex-random-sound"'

[[hooks.PermissionRequest]]
[[hooks.PermissionRequest.hooks]]
type = "command"
command = '"$HOME/.helpers/codex-random-sound"'
```

After adding these, run `/hooks` inside Codex and **trust** the new `codex-random-sound` hooks — Codex will not run non-managed command hooks until you do, so the config above stays silent until it's trusted (and changing a hook definition later requires re-trusting it).

On an older Codex without hooks, the legacy top-level `notify` key covers turn-completion only (no permission event). It must appear **before** any `[table]` header in the file:

```toml
notify = ["/bin/bash", "-c", "exec \"$HOME/.helpers/codex-random-sound\""]
```

#### Gemini CLI — `~/.gemini/settings.json`

`AfterAgent` fires when the agent loop ends (turn done); `Notification` fires on tool-permission prompts. **Gemini parses the hook's stdout as JSON**, so the command must print nothing on stdout — the `>/dev/null 2>&1; exit 0` guard below guarantees that (the helper is already stdout-silent, but the guard is belt-and-suspenders). Requires Gemini CLI v0.26+.

```json
{
  "hooks": {
    "AfterAgent": [
      { "hooks": [{ "type": "command", "command": "\"$HOME/.helpers/gemini-random-sound\" >/dev/null 2>&1; exit 0" }] }
    ],
    "Notification": [
      { "hooks": [{ "type": "command", "command": "\"$HOME/.helpers/gemini-random-sound\" >/dev/null 2>&1; exit 0" }] }
    ]
  }
}
```

> Event names and config paths above were verified against each tool's docs (mid-2026), but versions move fast — confirm against your installed build. The engine and symlinks are tested; the per-CLI glue is the part to sanity-check live. To test any of them directly: `<TOOL>_RANDOM_SOUND_DEBUG=1 ~/.helpers/<tool>-random-sound` should print and play a pick.

### Do Not Disturb / Focus

The helper exits silently while any macOS Focus / Do Not Disturb mode is engaged, so cmux stops ringing the moment you toggle on DND from Control Center.

It's checked live on every notification, and **any** Focus counts — not just Do Not Disturb:

| Focus active | cmux sound |
| --- | --- |
| Do Not Disturb | 🔇 silent |
| Work | 🔇 silent |
| Sleep | 🔇 silent |
| Reduce Interruptions | 🔇 silent |
| Nap | 🔇 silent |
| Driving | 🔇 silent |
| _(none)_ | 🔊 plays |

If *any* Focus is on, cmux stays quiet; with no Focus engaged, it plays. Toggle a Focus on/off and the very next notification reflects it — no reload needed.

**One-time setup** (the helper relies on a user-created Shortcut because macOS Tahoe retired every other shell-accessible Focus signal — `notifyutil` keys are dead, and `~/Library/DoNotDisturb/DB/Assertions.json` is now Full-Disk-Access-gated):

1. Open the **Shortcuts** app.
2. **File → New Shortcut**.
3. Name it exactly `cmux-focus-check` (the helper looks for that name).
4. In the action search panel, find **"Get Current Focus"** and drag it in. That's the whole shortcut — its output (the focus name, or empty when no focus) becomes the shortcut's return value.
5. Save (⌘S). No need to add it to the Dock or menu bar.

Verify it works (turn DND on first, then off, and re-run between):

```bash
tmp=$(mktemp -t focus.XXXXXX)
shortcuts run cmux-focus-check --output-path "$tmp" --output-type public.plain-text
cat "$tmp"; echo
rm -f "$tmp"
```

You should see the focus name (e.g. `Do Not Disturb`) when one is active, empty when none is.

> The **first** time the shortcut runs, macOS may show a one-time permission prompt to let it read your Focus state — approve it. It won't ask again. (If it's ever declined or unanswered, the helper just fails open and plays the sound, so cmux is never silenced by a missing grant.)

The standard cmux notification banner is unaffected — only this helper's random-sound playback is suppressed. macOS itself decides whether the OS-rendered banner appears based on cmux's per-app Focus filter settings.

To bypass the check (debugging, or you want sound during DND for a specific cmux you've otherwise allowed through), set `CMUX_RANDOM_SOUND_IGNORE_DND=1`. If `shortcuts` is missing or the `cmux-focus-check` shortcut doesn't exist on the machine, the helper fails open and plays the sound — a broken probe never silences cmux. Cost is ~0.6–0.9s of CLI overhead per notification (Apple's Shortcuts runtime is not fast); the sound itself is backgrounded so cmux's notification handling never blocks. If that latency becomes painful across more machines, the longer-term plan is the [`notifyctl` sketch PRD](tasks/prd-notifyctl.md) — a single FDA-grantable Go binary that reads the DND state directly.

Re-normalize after dropping new files into `dotfiles/cmux/` so they match the existing loudness:

```bash
brew install ffmpeg
pipx install ffmpeg-normalize  # one-time

ffmpeg-normalize dotfiles/cmux/*.wav \
  -nt ebu -t -16 -tp -1.5 -lrt 11 \
  -of /tmp/cmux-normalized -ar 44100 -c:a pcm_s16le -ext wav -f
ffmpeg-normalize dotfiles/cmux/*.mp3 \
  -nt ebu -t -16 -tp -1.5 -lrt 11 \
  -of /tmp/cmux-normalized -ar 44100 -c:a libmp3lame -b:a 128k -ext mp3 -f

cp /tmp/cmux-normalized/* dotfiles/cmux/
```

```bash
newrepo                 # run from anywhere
newrepo --help          # usage info
newrepo my-app ~/src    # non-interactive
```

## Prerequisites

- `curl` (pre-installed on macOS and most Linux)
- `sudo` access
- **macOS:** [Homebrew](https://brew.sh/) and Xcode Command Line Tools (`xcode-select --install`)
- **Linux:** `dnf` package manager (Fedora)
- `jq` and `zsh` are auto-installed if missing (via `brew` or `dnf`)

## TODO
- [ ] Add ~/.aws and similar credentials — tie in with the .secrets format.

## Third-Party Notices

### dotfiles/cmux/ — notification sound pool

All audio files under `dotfiles/cmux/` are licensed via [Envato Elements](https://elements.envato.com/license-terms), licensed to Jonathan Porta for use in this dotfiles configuration. The Envato Elements license is **non-transferable** — if you fork this repo, you'll need your own license (or replace the files with your own sounds) to use these assets.

| File | Title | Author / Source |
|---|---|---|
| `dingding.wav` | Media Help | sonic-boom — [https://elements.envato.com/media-help-NKYMQHD](https://elements.envato.com/media-help-NKYMQHD) (licensed 2026-04-26; previously committed as `dotfiles/cmux-notification.wav`) |
| `british-detective-can-i-ask-you-something.wav` | British Detective Stock Lines Vocal Female Can I Ask You Something | Envato Elements (supplied via [issue #26](https://github.com/JonathanPorta/dotfiles/issues/26)) |
| `british-male-what-do-you-think.wav` | Vox Male What Do You Think Uk | Envato Elements (supplied via [issue #26](https://github.com/JonathanPorta/dotfiles/issues/26)) |
| `english-warrior-can-you-help-me.wav` | English Warrior Dialogue Vocal Can You Help Me Male 30s Voice | Envato Elements (supplied via [issue #26](https://github.com/JonathanPorta/dotfiles/issues/26)) |
| `wizard-i-am-ready-and-waiting.wav` | Wizard Dialogue I Am Ready And Waiting | Envato Elements (supplied via [issue #26](https://github.com/JonathanPorta/dotfiles/issues/26)) |
| `man-asking-for-help-{1..4}.wav`, `.mp3` | Man Asking For Help (4 variants × wav + mp3) | Envato Elements (supplied via [issue #26](https://github.com/JonathanPorta/dotfiles/issues/26)) |
