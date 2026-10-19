# PRD: Installer Fixes for dnf4/dnf5 and Quiet Re-Runs

## Summary

Running `run.sh` on a Fedora 36 host (dnf4) and a Fedora 42 host (dnf5) turned
up four installer bugs and several steps that fail or make noise when run a
second time. This change fixes those with small checks in the style the
scripts already use, adds an end-of-life warning, and adds a managed tmux
config.

## Codebase Analysis

- `installation/util.sh` installed `gh` with dnf5-only commands
  (`dnf5-plugins`, `config-manager addrepo --from-repofile`), then ran
  `gh extension install` unconditionally, which fails when `gh` is missing or
  not logged in.
- `installation/gpg.sh` was committed without its execute bit, so `all.sh`
  failed with `permission denied` on every platform.
- `installation/python3.sh` installed poetry with `pipx`, which nothing
  installs. `uv` is installed earlier in the same script.
- git-lfs on Fedora came from a packagecloud script pinned to `fedora/32`.
  Fedora packages git-lfs itself. The "already installed" check,
  `exists "git lfs install"`, could never pass.
- `oh-my-zsh.sh` re-ran the oh-my-zsh installer and re-cloned plugins on every
  run. `node.sh` checked for `nvm` as a command, but it is a shell function.
  `vim.sh` already uses the `if [ -d ... ]` pattern adopted here.
- `fedora.sh` failed hard when the Fedy Copr has no build for the release.
- `agent-config.sh` skipped when the system Python was older than 3.11.

## Acceptance Criteria

1. `gh` installs on both dnf4 and dnf5. Each run downloads and validates the
   repo file before replacing it. A failed or truncated download preserves
   the installed file and reports the skipped refresh and gh installation.
   gh extensions install only when `gh` is logged in and the extension
   is not already present. Otherwise a hint to run `gh auth login` is printed.
2. `installation/gpg.sh` is executable.
3. poetry installs with `uv tool install poetry`, and `~/.local/bin` is on
   PATH for the rest of `python3.sh`.
4. git-lfs installs from the platform package manager, and the "already
   installed" check works.
5. oh-my-zsh, spaceship, zsh-completions, dogesay and nvm are skipped when
   already present, using one-line existence checks.
6. Fedy prints one skip message and continues when its Copr has no build.
   agent-config uses a `uv`-managed Python 3.11+ when the system Python is too
   old, unless `PYTHON3_BIN` is set.
7. `run.sh` warns, without ever failing, when the Fedora release is past end
   of life. It is silent on macOS, on supported releases, and when offline.
8. `dotfiles/.tmux.conf` is linked by `symlink.sh`. It enables
   `set-clipboard` and binds prefix + `Y` to copy the full scrollback.

Out of scope, tracked in a follow-up issue: `.old<timestamp>` backups piling
up on re-runs, scripts sourcing `~/.zshrc` and the noise that causes, and the
nvm checkout staying on an old tag.

## Evidence

| AC | Proof |
|---|---|
| 1 | Repo-file URL serves `[gh-cli]` with the current `gpgkey`. dnf4 accepts `--repo`. Extension guard checked on three hosts: it skips when the extension is present and would install when it is missing. Review F1: `bash tests/test-gh-repo-refresh.sh` reproduces the original data loss and passes 14 cases after the fix: failed/partial/invalid downloads preserve the old bytes; staging/rename failures preserve them too; valid and rotated-key definitions install as mode 0644 and reach the common `dnf install -y gh --repo gh-cli` command. Temporary files are removed and errors are not reported as success. Package commands are mocked; no live Fedora installation was run for this correction. |
| 2 | `git ls-files -s installation/gpg.sh` reports mode `100755`. |
| 3 | `zsh -n installation/python3.sh` passes. |
| 4 | `git lfs version` check returns installed on macOS, Fedora 36 and Fedora 42. On Fedora 36, git-lfs comes from `@updates`. |
| 5 | `zsh -n` passes on `oh-my-zsh.sh` and `node.sh`. |
| 6 | On Fedora 36 (Python 3.10) with a temp `HOME`, uv supplied Python 3.12, a re-run reused it, and with no uv the step skipped. `PYTHON3_BIN` pinned to a bad Python still skips. `tests/test-agent-config.sh` passes. The Fedy branch needs a real run, because `copr enable` requires sudo. |
| 7 | Warns on Fedora 36 and Fedora 42. Silent on macOS, on a simulated Fedora 44, and with an unreachable Bodhi. The run continues in every case. |
| 8 | Config loads on tmux 3.8 and 3.3a, and `Y` is bound. The capture command copied all 200 scrollback lines from a 5-line pane. The symlink block links when the file is absent, does nothing when already linked, and backs up an existing file. Clipboard delivery through OSC 52 needs an attached terminal, so it was not tested. |
