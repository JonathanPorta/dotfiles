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
| **Purpose** | Clones this repo (via HTTPS), symlinks shell configs (`.zshrc`, `.zshenv`, `.zprofile`, `.gitignore_global`, `.chruby`, `.helpers`) into `$HOME`, symlinks `cmux-notification.wav` into `~/.sounds/` and renders `~/.config/cmux/settings.json` from the JSONC template, installs `jq` and `zsh` if missing, and syncs GitHub `authorized_keys`. |
| **Idempotency** | **Mostly safe to re-run.** If the repo already exists it does a `git fetch` instead of cloning. Existing dotfiles in `$HOME` are renamed to `*.old<timestamp>` before re-linking, so nothing is silently lost. |
| **Destructive?** | Moves existing `.zshrc`, `.zshenv`, `.zprofile`, `.gitignore_global`, `.chruby` to timestamped backups. Truncates `authorized_keys`. |

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
| `util.sh` | Shell utility functions like `externaldns` and `curlr` (sourced automatically by `.profile`). |

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
