# claude-names.zsh: name Claude sessions after their cmux workspace.
#
# Typing `claude` or `claude-az` inside a cmux workspace starts the session as
# "<workspace>-00", "<workspace>-01", ... taking the lowest number that no live
# session in any Claude profile already holds. <workspace> is the title shown in
# the cmux sidebar, as written, with '/' turned into '-'; a workspace cmux
# titled itself uses its folder name. It runs once, at launch, in the shell: no hook, no
# daemon, no model usage, and nothing enforces the name afterward.
#
# Left untouched (launched exactly as before):
#   - outside cmux, or when the workspace cannot be found
#   - the Scratch workspace, which keeps Claude's own derived names
#   - an explicit -n/--name, a resume (-r/--resume, -c/--continue, --from-pr,
#     --session-id), print mode (-p/--print), and subcommands (mcp, doctor, ...)
#
# CLAUDE_NAMES_DRY_RUN=1 prints the command instead of running it.

typeset -ga _claude_names_skip_workspaces=(scratch)
typeset -ga _claude_names_session_dirs=("$HOME/.claude/sessions" "$HOME/.claude-az/sessions" "$HOME/.claude-w/sessions")

# The workspace title as written; only '/' becomes '-' and outer spaces go.
_claude_names_base() {
  setopt localoptions extendedglob
  local s=${1//\//-}
  s=${s##[[:space:]]##}
  print -r -- ${s%%[[:space:]]##}
}

# Print the name to use, or nothing to leave the launch alone.
_claude_names_pick() {
  setopt localoptions extendedglob
  [[ -n $CMUX_WORKSPACE_ID ]] || return 0
  (( $+commands[cmux] && $+commands[jq] )) || return 0

  local arg
  case $1 in
    agents|attach|auth|auto-mode|doctor|gateway|import|install|logs|mcp|plugin|purge|respawn|rm|setup-token|stop|ultrareview|update) return 0 ;;
  esac
  for arg in "$@"; do
    case $arg in
      -n|--name|--name=*|-r|--resume|--resume=*|-c|--continue|--from-pr|--from-pr=*|--session-id|--session-id=*|-p|--print) return 0 ;;
    esac
  done

  # Custom workspace title, or the folder name when cmux titled it itself.
  local title
  title=$(CMUX_QUIET=1 cmux --json workspace list 2>/dev/null | jq -r --arg id "$CMUX_WORKSPACE_ID" '
    .workspaces[]? | select(.id == $id)
    | if .has_custom_title then .title else (.current_directory | split("/") | last) end' 2>/dev/null)
  [[ -n $title ]] || return 0

  local base=$(_claude_names_base "$title")
  [[ -n $base ]] || return 0
  (( ${_claude_names_skip_workspaces[(Ie)${base:l}]} )) && return 0

  # Ordinals already held by live sessions in any profile.
  local -a files used
  local dir pid name n
  for dir in $_claude_names_session_dirs; do
    files+=("$dir"/*.json(N))
  done
  if (( $#files )); then
    jq -r --arg p "$base-" '
      select((.name // "") | startswith($p)) | "\(.pid) \(.name)"' $files 2>/dev/null |
    while read -r pid name; do
      n=${name#"$base-"}
      [[ $name == "$base-$n" && $n == [0-9][0-9] ]] || continue
      kill -0 $pid 2>/dev/null && used+=($n)
    done
  fi

  for n in {00..99}; do
    (( ${used[(Ie)$n]} )) || { print -r -- "$base-$n"; return 0; }
  done
}

# Usage: _claude_names_launch <count> <count words of env prefix> <claude args...>
_claude_names_launch() {
  local count=$1; shift
  local -a pre=("${(@)argv[1,count]}")
  shift $count
  local name=$(_claude_names_pick "$@")
  local -a cmd=("${pre[@]}" claude)
  [[ -n $name ]] && cmd+=(--name "$name")
  cmd+=("$@")
  if [[ -n $CLAUDE_NAMES_DRY_RUN ]]; then
    print -r -- would run: ${(@q-)cmd}
  else
    command "${cmd[@]}"
  fi
}

unalias claude claude-az 2>/dev/null
claude()    { _claude_names_launch 3 env -u CLAUDE_CONFIG_DIR "$@" }
claude-az() { _claude_names_launch 2 env CLAUDE_CONFIG_DIR="$HOME/.claude-az" "$@" }
