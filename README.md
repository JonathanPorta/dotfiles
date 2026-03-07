# dotfiles

My configuration files for some of my tools.

## Supported Platforms

- **macOS** (Apple Silicon and Intel)
- **Fedora Linux**

## Features

### 1. Bootstrap SSH (`hello-world.sh`)

Sets up SSH on a fresh machine: generates an ed25519 key pair, pulls your GitHub public keys into `authorized_keys`, and enables the SSH daemon. Auto-installs `jq` if missing.

**Run this first on a new machine**, then add the generated public key to your GitHub account before proceeding to the full install.

```bash
curl https://raw.githubusercontent.com/JonathanPorta/dotfiles/master/hello-world.sh | bash
```

After running, add your new public key to GitHub:
```bash
cat ~/.ssh/id_ed25519.pub
# Copy output → GitHub → Settings → SSH and GPG keys → New SSH key
```

### 2. Full Dotfiles Install (`init.sh` → `run.sh`)

Clones this repo (via HTTPS), symlinks dotfiles, installs oh-my-zsh + plugins, and sets up dev tools (node, ruby, python, go, etc.). Auto-installs `git`, `jq`, and `zsh` if missing.

**Step 1:** Run the init script:
```bash
curl https://raw.githubusercontent.com/JonathanPorta/dotfiles/master/init.sh | bash
```

**Step 2:** Restart your shell into zsh, then run:
```bash
zsh -lc "$HOME/devel/portaj/dotfiles/run.sh"
```

## Prerequisites

- `curl` (pre-installed on macOS and most Linux)
- `sudo` access
- **macOS:** [Homebrew](https://brew.sh/) and Xcode Command Line Tools (`xcode-select --install`)
- **Linux:** `dnf` package manager (Fedora)
- `jq` and `zsh` are auto-installed if missing (via `brew` or `dnf`)

## TODO

- [ ] Cleanup notes and force push over all previous history to remove potentially unwanted info from leaking. :/
- [ ] Add ~/.aws and similar credentials - tie in with the .secrets format.
