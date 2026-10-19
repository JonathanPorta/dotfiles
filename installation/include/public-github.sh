#!/usr/bin/env bash

# Package sources live on public GitHub even when the login shell defaults to
# enterprise GitHub. Use a private snapshot so nested Git processes inherit the
# same routing, while proxies, certificate paths, and credentials remain usable.
# This helper is shared by the Bash bootstrap and the Zsh installers.
public_github() (
  local config_dir scope entry key value public_prefix skip_rewrite original_umask
  original_umask=$(umask)
  umask 077
  config_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-github.XXXXXX") || exit 1
  trap 'rm -rf "$config_dir"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  git config --null --list --includes --show-scope >"$config_dir/source" || exit 1
  : >"$config_dir/config"
  while IFS= read -r -d '' scope && IFS= read -r -d '' entry; do
    # Do not carry the caller's repository settings into newly cloned repos.
    case "$scope" in local|worktree) continue ;; esac
    key=${entry%%$'\n'*}
    if [ "$entry" = "$key" ]; then value=true; else value=${entry#*$'\n'}; fi
    case "$key" in
      # Includes have already been expanded. Keeping them would reload rewrites.
      include.path|includeif.*.path|github.host|hub.host) continue ;;
      url.*.insteadof|url.*.pushinsteadof)
        # Keep rewrites for other hosts (e.g. private Homebrew taps).
        skip_rewrite=false
        for public_prefix in https://github.com/ http://github.com/ git://github.com/ ssh://git@github.com/ git@github.com:; do
          if [[ "$value" == "$public_prefix"* || "$public_prefix" == "$value"* ]]; then
            skip_rewrite=true
            break
          fi
        done
        [ "$skip_rewrite" = false ] || continue
        ;;
    esac
    git config --file "$config_dir/config" --add "$key" "$value" || exit 1
  done <"$config_dir/source"
  rm -f "$config_dir/source"

  export GIT_CONFIG_GLOBAL="$config_dir/config" GIT_CONFIG_NOSYSTEM=1
  # Command-scope settings were included above; do not apply them a second time.
  export GIT_CONFIG_COUNT=0
  unset GIT_CONFIG_PARAMETERS GIT_CONFIG
  # GHE.com also consumes these variables. Do not reuse an explicitly selected
  # enterprise host's token on github.com; let gh use its saved public login.
  case "${GH_HOST:-github.com}" in
    github.com) ;;
    *) unset GH_TOKEN GITHUB_TOKEN ;;
  esac
  export GH_HOST=github.com
  unset GH_REPO
  umask "$original_umask"
  "$@"
)
