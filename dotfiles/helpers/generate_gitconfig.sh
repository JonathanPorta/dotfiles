#!/usr/bin/env bash

# copy-pasta'd from https://stackoverflow.com/a/42457815/555017
SCRIPT_GENERATOR_PATH="$(cd $(dirname "$0") && pwd)/$(basename "$0")"
echo "Generating $HOME/.gitconfig using $SCRIPT_GENERATOR_PATH..."

cat <<EOF > $HOME/.gitconfig
# This gitconfig was generated via $SCRIPT_GENERATOR_PATH.
# Edit that file, not this one!

[user]
  name = Jonathan Porta
  email = jonathan@jonathanporta.com
  # Set this to your GPG signing subkey ID (append ! to force that exact subkey)
  # signingkey = 0xABCD1234ABCD1234!

[core]
  excludesfile = $HOME/.gitignore_global
  pager = less -F -X

[init]
  defaultBranch = main

[help]
  autocorrect = 1

[rerere]
  enabled = 1

[push]
  # 'current' pushes to a remote branch with the SAME NAME as the local one,
  # which prevents 'git push' from landing on master/main if a local branch
  # happens to track origin/master (e.g. via autosetuprebase). Combined with
  # autoSetupRemote, the first push of a new branch auto-creates the upstream.
  default = current
  autoSetupRemote = true

[fetch]
  prune = true

[alias]
  lg = log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%C(bold blue)<%an>%Creset' --abbrev-commit
  ll = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
  l  = log --oneline --decorate
  co = checkout
  ci = commit
  s = status
  ss = status -sb
  p = push

  clean-branches = !sh -c 'git branch --merged main | grep -v main | xargs -n 1 git branch -d'

  up = "!f() { \\
    current=\$(git symbolic-ref --quiet --short HEAD || true); \\
    track=\$(git for-each-ref --format='%(upstream:track)' \"refs/heads/\$current\" 2>/dev/null); \\
    if [ \"\$track\" = \"[gone]\" ]; then \\
      echo \"Current branch '\$current' has a gone upstream; refusing to pull.\"; \\
      echo \"Switch to main/master, or run 'git prune-gone-force' to clean up.\"; \\
      return 1; \\
    fi; \\
    git pull --rebase --autostash && \\
    git prune-gone; \\
  }; f"

  prune-gone = "!f() { \\
    git -c fetch.pruneTags=false fetch --all --prune; \\
    current=\$(git symbolic-ref --quiet --short HEAD || true); \\
    git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | \\
      awk '\$2 == \"[gone]\" { print \$1 }' | \\
      while read branch; do \\
        if [ \"\$branch\" = \"\$current\" ]; then \\
          echo \"Skipping current branch with gone upstream: \$branch\"; \\
        elif git branch -d -- \"\$branch\" 2>/dev/null; then \\
          echo \"deleted \$branch ([gone] upstream)\"; \\
        else \\
          echo \"kept \$branch ([gone] but not -d-deletable; use 'git prune-gone-force' to chainsaw)\"; \\
        fi; \\
      done; \\
  }; f"

  prune-gone-force = "!f() { \\
    git -c fetch.pruneTags=false fetch --all --prune; \\
    current=\$(git symbolic-ref --quiet --short HEAD || true); \\
    git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | \\
      awk '\$2 == \"[gone]\" { print \$1 }' | \\
      while read branch; do \\
        if [ \"\$branch\" = \"\$current\" ]; then \\
          echo \"Skipping current branch with gone upstream: \$branch\"; \\
        else \\
          git branch -D -- \"\$branch\" && echo \"force-deleted \$branch ([gone] upstream)\"; \\
        fi; \\
      done; \\
  }; f"

[branch]
  autosetuprebase = always

[color "branch"]
  current = yellow reverse
  local = yellow
  remote = green

[color "diff"]
  meta = yellow bold
  frag = magenta bold
  old = red bold
  new = green bold
  whitespace = red reverse

[color "status"]
  added = yellow
  changed = green
  untracked = cyan

[filter "lfs"]
  clean = git-lfs clean -- %f
  smudge = git-lfs smudge -- %f
  required = true
  process = git-lfs filter-process

[github]
  user = jonathanporta

[gpg]
  program = gpg2

[commit]
#  gpgsign = true

[tag]
#  gpgsign = true

[url "ssh://git@github.com/"]
  username = jonathanporta
  insteadOf = https://github.com/

#[url "https://github.com/"]
# username = jonathanporta
# insteadOf = ssh://git@github.com/
# insteadOf = git@github.com:

#[url "ssh://git@$WORK_GH_HOSTNAME/"]
#  username = $WORK_GH_USERNAME
#  insteadOf = https://$WORK_GH_HOSTNAME/

EOF
