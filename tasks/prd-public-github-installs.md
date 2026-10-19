# Reliable package installation and reruns

## Problem and scope

Work-laptop Git URL rewrites and GitHub CLI host defaults redirect public
package installs to an enterprise host. The reported failure is the
vilmibm/gh-screensaver extension. Bootstrap and package downloads must target
github.com without changing the user's normal Git or GitHub CLI configuration.

Reruns also invoke Homebrew for installed formulae, and Python tool installation
uses `pip3 --user`, which fails with externally managed Python distributions.
Handle inherited Python environments before installing tools and report the
selected Python. Explain third-party tap trust without granting it automatically.

## Codebase analysis

- init.sh is a standalone Bash bootstrap: it clones dotfiles or fetches an
  existing checkout before repository helpers are available.
- run.sh loads installation/include/lib.sh and launches installation/all.sh.
  The individual Zsh installers load the same library.
- util.sh checks gh authentication without a hostname and installs the
  screensaver with a bare owner/repo name.
- node.sh, oh-my-zsh.sh, and vim.sh clone public repositories. The downloaded
  oh-my-zsh installer also invokes Git in a child shell. Homebrew can invoke
  Git while installing packages.
- Git insteadOf values are multi-valued; an empty or equal-length command
  override does not cancel an existing rewrite (verified with real Git).
- No Makefile exists. Existing validation uses Bash scripts under tests/.
  Keep that command surface for this bounded fix.
- PR #41 is merged. Create a follow-up PR from current master.

## Approach

Add a Bash/Zsh helper that runs a command with github.com selected and a private
temporary Git configuration. Read system/global/command configuration without
repository context, then flatten the resulting unconditional includes and
omit URL rewrites that affect public GitHub and expanded include directives,
retaining unrelated settings such as proxies and certificate paths. Scope the
environment to a subshell and clean up
temporary configuration afterward. Explicit repository URLs select public GitHub
even when the caller is inside an enterprise repository.

Use the helper around public Git clones, the downloaded oh-my-zsh installer,
Homebrew installs, and GitHub CLI extension commands. init.sh loads the helper
beside itself when run locally, or downloads it from the same public dotfiles
repository when invoked as a standalone/piped bootstrap.

Check the package database before calling Homebrew or dnf. Keep explicit dnf
options and RPM file/URL installs. Remove active venv/Conda bin paths only in the
Python install process. Reuse an available Python 3.11+ or let uv install 3.12
(matching the existing agent-config fallback), and use uv's isolated tool
environments for virtualenv, pipenv, and Poetry.

## Acceptance criteria

- AC-1: The screensaver's auth check names github.com, its install uses the full
  public URL, and failures identify the public login command.
- AC-2: Public Git clone/fetch commands and nested installer Git processes avoid
  inherited enterprise URL rewrites while preserving proxy and TLS settings.
- AC-3: Both bootstrap clone and existing-checkout fetch explicitly target the
  public dotfiles repository. The piped bootstrap still works.
- AC-4: User configuration files and the parent shell environment are unchanged;
  temporary files are private and removed, including on command failure.
- AC-5: Existing installer regression suites continue to pass.
- AC-6: Shared package installation skips installed Homebrew formulae and Fedora
  packages, keeps package-manager options, and installs only missing packages.
- AC-7: Python setup excludes inherited virtualenv/Conda paths in its own process,
  finds uv in its user install directory, reports an existing Python, and installs
  virtualenv, pipenv, and Poetry through isolated uv tools. No global/user pip
  installs or externally-managed protection bypasses are used.
- AC-8: README explains Homebrew's third-party tap trust and explicit user options.
- AC-9: Repository-conditional credentials must not become global package-download
  settings. Read the snapshot with Git repository selectors cleared and discovery
  bounded outside any repository, even when TMPDIR is inside the work checkout.
  Preserve host-qualified credential settings without widening their host scope.

No changes to work-repository remotes, persistent GitHub host defaults, or saved
credentials are part of this feature. Live package installation is not required
for local validation; use real Git URL resolution and controlled command mocks.

## Validation

- `bash tests/test-public-github.sh`: real Git resolution in Bash/Zsh; system,
  global, included, and command settings; nested processes, original config and
  environment preservation, argument boundaries, cleanup, and failure status.
  The F1 negative control uses a gitdir-conditional authorization canary and
  credential helper, with TMPDIR inside that repo and explicit Git selectors.
  Work-only credentials must be absent from the public child's effective and
  generated global config; host-specific headers must stay on their own hosts.
- `bash tests/test-installer-routing.sh`: screensaver install/skip/public-login
  hint; local and piped bootstrap, existing enterprise origin, download failure.
- `bash tests/test-installer-packages.sh`: mixed/all-installed/missing packages,
  dnf options, RPM paths, errors, active Python environments, existing uv/Python,
  isolated tools, reruns, and missing-interpreter/download failure paths.
- Existing `test-gh-repo-refresh.sh` (14 scenarios) and `test-agent-config.sh`.
- Bash/Zsh syntax validation and `git diff --check`.

Tests use controlled package commands; a live install on a macOS work laptop
is outside this environment's validation.
