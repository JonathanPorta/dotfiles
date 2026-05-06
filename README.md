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
| **Purpose** | Clones this repo (via HTTPS), symlinks shell configs (`.zshrc`, `.zshenv`, `.zprofile`, `.gitignore_global`, `.chruby`, `.helpers`) into `$HOME`, directory-symlinks `dotfiles/cmux/` (the cmux notification-sound pool) into `~/.sounds/cmux/` and renders `~/.config/cmux/settings.json` from the JSONC template (which delegates per-notification sound playback to the `cmux-random-sound` helper), installs `jq` and `zsh` if missing, and syncs GitHub `authorized_keys`. |
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
| `cmux-random-sound` | Picks a random audio file from `~/.sounds/cmux/` and plays it via `afplay` in the background. Invoked by cmux's `notifications.command` hook on every notification. Volume: `$CMUX_RANDOM_SOUND_VOLUME` env var > `~/.config/cmux/random-sound-volume` file > `0.4` default (loudness-normalized clips don't jumpscare). Set `$CMUX_RANDOM_SOUND_DEBUG=1` to print the picked file to stderr. Exits silently if the directory is missing/empty or the platform isn't darwin. |
| `util.sh` | Shell utility functions like `externaldns` and `curlr` (sourced automatically by `.profile`). |

### Adding more cmux notification sounds

The cmux notification sound is randomized per-notification — one file is picked at random from `~/.sounds/cmux/` each time. To add a new sound:

1. Drop a `.wav`, `.mp3`, `.aiff`, `.aif`, or `.m4a` file into `~/.sounds/cmux/` (or into `dotfiles/cmux/` if you want it tracked in the repo — the install symlinks the whole directory).
2. No reload needed for new sound files — the helper re-scans the directory on every notification, so the next ding picks them up automatically. Reload cmux config (`cmd+shift+,`) only if you've also edited `dotfiles/cmux-settings.json`.

All sounds in `dotfiles/cmux/` are loudness-normalized to **-16 LUFS** (EBU R128) so no single clip is dramatically louder than the others. Playback volume defaults to `0.4` (40% of system volume) — quiet enough not to be a jumpscare, loud enough to notice. To override the default, the helper checks two sources in order:

1. **`$CMUX_RANDOM_SOUND_VOLUME`** environment variable. Easy from a shell — but **only effective if cmux inherits a shell environment.** If cmux is launched as a normal macOS GUI app (Dock, Spotlight, Finder), it will not source `.zshrc` and the env var won't be visible to the helper. If you launch cmux from a terminal, this works.
2. **`~/.config/cmux/random-sound-volume`** — a tiny single-line file with the float value. Works regardless of how cmux was launched. Recommended path for GUI users.

```bash
# Option 1: env var (shell-launched cmux)
export CMUX_RANDOM_SOUND_VOLUME=1.0   # full system volume
export CMUX_RANDOM_SOUND_VOLUME=0.2   # quieter than the default

# Option 2: config file (works with GUI-launched cmux too)
mkdir -p ~/.config/cmux && echo 0.6 > ~/.config/cmux/random-sound-volume
```

Useful range `0.0`–`1.0`; values above `1.0` amplify but may clip. To verify which sound is being picked, set `CMUX_RANDOM_SOUND_DEBUG=1` and run the helper directly — the picked file path is printed to stderr.

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
