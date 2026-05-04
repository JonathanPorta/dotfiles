# zmodload zsh/zprof
# https://unix.stackexchange.com/a/71258/103099
# https://stackoverflow.com/a/18187389

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
# ZSH_THEME="robbyrussell"
ZSH_THEME="spaceship"
SPACESHIP_BATTERY_SHOW=false

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# source $ZSH/plugins/kube-ps1/kube-ps1.plugin.zsh
# PROMPT='$(kube_ps1)'$PROMPT
plugins=(zsh-completions pipenv)
# plugins=()
# RPS1='$(kubectx_prompt_info)'


ZSH_DISABLE_COMPFIX=true
if [ -f "$ZSH/oh-my-zsh.sh" ]; then
  source $ZSH/oh-my-zsh.sh
fi

# Bring in my env stuff that isn't just zsh config
# TODO: Moved to .zshenv but need to break up these files into stuff that can be loaded when needed vs not.
# source $HOME/dotfiles/.profile

# Moved to .profile
# source $HOME/dotfiles/generate_gitconfig.sh

if command -v complete >/dev/null 2>&1 && [ -f /usr/bin/terraform ]; then
  complete -o nospace -C /usr/bin/terraform terraform
fi
if command -v complete >/dev/null 2>&1 && [ -f /usr/local/bin/aws_completer ]; then
  complete -C '/usr/local/bin/aws_completer' aws
fi

SPACESHIP_PROMPT_ASYNC=true


if [ -f "$HOME/dotfiles/.profile" ]; then
  . $HOME/dotfiles/.profile
fi

# Added by Code Puppy installer on Fri Mar 20 15:06:43 PDT 2026
if [ -f "$HOME/.code-puppy-venv/bin/code-puppy" ]; then
  alias code-puppy="$HOME/.code-puppy-venv/bin/code-puppy"
fi

# ----------------------------------------------------------------------------
# Disable cmux's PR-status polling.
#
# cmux's shell integration (cmux-zsh-integration.zsh) starts a background
# `_cmux_start_pr_poll_loop` per shell that runs `gh pr view <branch>` every
# 45s to display PR status in the cmux UI. Across many cmux workspaces and
# shells this aggregates to ~100 GraphQL points/min and saturates the
# personal 5000/hr GitHub API quota every ~50 minutes — blocking all other
# tooling that authenticates as the user (gh CLI, Copilot, Claude, etc.).
#
# Override the function to a no-op AFTER cmux's integration has loaded, and
# bump the interval to be effectively never as a belt-and-suspenders measure.
# Currently-running shells need `_cmux_stop_pr_poll_loop` invoked manually
# (or just close + reopen the tab).
#
# Note: cmux ALSO polls from the app process itself (`gh pr checks` /
# `gh pr list`) which this override does NOT stop — that requires quitting
# and restarting cmux. Filed/will file as a feature request for an in-app
# disable toggle.
# ----------------------------------------------------------------------------
_cmux_start_pr_poll_loop() { return 0; }
typeset -g _CMUX_PR_POLL_INTERVAL=999999

# zprof
