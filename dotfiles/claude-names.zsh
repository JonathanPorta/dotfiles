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
#
# Both commands also resume a session from either profile by UUID; see
# "Cross-profile resume" below.

typeset -ga _claude_names_skip_workspaces=(scratch)
typeset -ga _claude_names_subcommands=(agents attach auth auto-mode doctor gateway import install logs mcp plugin purge respawn rm setup-token stop ultrareview update)
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
  (( ${_claude_names_subcommands[(Ie)$1]} )) && return 0
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

# ----------------------------------------------------------------------------
# Cross-profile resume. The command picks the ACCOUNT; the lookup searches BOTH
# histories. `claude --resume <uuid>` and `claude-az --resume <uuid>` look for
# <uuid>.jsonl under the invoked profile's projects/ first, then the other's.
#   - found in the invoked profile: the UUID is passed through unchanged, so an
#     ordinary resume continues the same session exactly as before;
#   - found only in the other profile: the UUID is replaced by the transcript's
#     absolute path (Claude Code loads a `.jsonl` resume value as a file and
#     continues it under a new session id in the invoked profile; the other
#     profile's transcript is read, never written);
#   - found in neither, ambiguous, or unreadable: say so on stderr and do not
#     launch (exit 1 for not found, 2 for ambiguity or a lookup failure).
# Accepted forms: --resume UUID, --resume=UUID, -r UUID. Anything else (a bare
# --resume for the picker, a name, a path, --continue, subcommands) passes
# through untouched. Progress goes to stderr only, so -p / JSON output on
# stdout stays clean.

typeset -gA _claude_profile_label=(personal Claude az Claude-AZ)
typeset -gA _claude_profile_account=(personal 'personal account' az 'Azimuth account')
typeset -gA _claude_profile_other=(personal az az personal)

_claude_profile_dir() {
  case $1 in
    personal) print -r -- "$HOME/.claude" ;;
    az) print -r -- "$HOME/.claude-az" ;;
  esac
}

# Usage: _claude_resume_find <profile-dir> <uuid>
# Sets reply to the matching transcripts. Returns 3, with _claude_resume_err
# naming what could not be read, when the search itself failed.
_claude_resume_find() {
  local p="$1/projects" sub
  local -a bad
  reply=()
  _claude_resume_err=
  [[ -e $p ]] || return 0
  if [[ ! -d $p || ! -r $p || ! -x $p ]]; then
    _claude_resume_err=$p
    return 3
  fi
  for sub in "$p"/*(N/); do
    [[ -r $sub && -x $sub ]] || bad+=("$sub")
  done
  # An unreadable project directory could hold another copy, so a visible
  # match is not proof of a unique one: refuse rather than pick it.
  if (( $#bad )); then
    _claude_resume_err=${(j:, :)bad}
    return 3
  fi
  reply=("$p"/*/"$2".jsonl(N-.))
  return 0
}

# Usage: _claude_resume_locate <self> <id>
# Sets REPLY to the transcript path to launch with, or to "" to keep the UUID.
_claude_resume_locate() {
  local self=$1 id=$2 key dir
  local other=${_claude_profile_other[$self]}
  local -a reply
  REPLY=
  for key in $self $other; do
    dir=$(_claude_profile_dir $key)
    if [[ $key == $self ]]; then
      print -u2 -r -- "[resume] Looking for $id in ${_claude_profile_label[$key]}..."
    else
      print -u2 -r -- "[resume] Not found. Looking in ${_claude_profile_label[$key]}..."
    fi
    if ! _claude_resume_find "$dir" "$id"; then
      print -u2 -r -- "[resume] Could not search ${_claude_profile_label[$key]} for $id: cannot read $_claude_resume_err"
      return 2
    fi
    if (( $#reply > 1 )); then
      print -u2 -r -- "[resume] Session $id is ambiguous in ${_claude_profile_label[$key]}; candidates:"
      print -u2 -rl -- "  "${^reply}
      return 2
    fi
    if (( $#reply == 1 )); then
      print -u2 -r -- "[resume] Found in ${_claude_profile_label[$key]}: ${reply[1]}"
      [[ $key == $self ]] || REPLY=${reply[1]}
      return 0
    fi
  done
  print -u2 -r -- "[resume] Session $id not found in ${_claude_profile_label[$self]} or ${_claude_profile_label[$other]}."
  return 1
}

# Usage: _claude_resume_rewrite <self> <claude args...>; sets reply to the
# arguments to launch with.
_claude_resume_rewrite() {
  setopt localoptions extendedglob
  local self=$1; shift
  local uuid='[[:xdigit:]](#c8)-[[:xdigit:]](#c4)-[[:xdigit:]](#c4)-[[:xdigit:]](#c4)-[[:xdigit:]](#c12)'
  local -a out
  local i=1 a id resumed=0 rc
  reply=("$@")
  (( ${_claude_names_subcommands[(Ie)$1]} )) && return 0
  while (( i <= $# )); do
    a=${argv[i]}
    if [[ $a == (--resume|-r) ]] && (( i < $# )) && [[ ${argv[i+1]} == ${~uuid} ]]; then
      id=${argv[i+1]}
      _claude_resume_locate $self $id; rc=$?
      (( rc == 0 )) || return $rc
      out+=("$a" "${REPLY:-$id}")
      resumed=1
      (( i += 2 ))
      continue
    fi
    if [[ $a == --resume=* && ${a#--resume=} == ${~uuid} ]]; then
      id=${a#--resume=}
      _claude_resume_locate $self $id; rc=$?
      (( rc == 0 )) || return $rc
      out+=("--resume=${REPLY:-$id}")
      resumed=1
      (( i++ ))
      continue
    fi
    out+=("$a")
    (( i++ ))
  done
  (( resumed )) && print -u2 -r -- "[resume] Launching ${_claude_profile_label[$self]} (${_claude_profile_account[$self]})."
  reply=("${out[@]}")
  return 0
}

# Usage: _claude_profile_launch <self> <count> <count words of env prefix> <claude args...>
_claude_profile_launch() {
  local self=$1 count=$2; shift 2
  local -a pre=("${(@)argv[1,count]}")
  shift $count
  local -a reply
  _claude_resume_rewrite $self "$@" || return
  _claude_names_launch $count "${pre[@]}" "${reply[@]}"
}

unalias claude claude-az 2>/dev/null
claude()    { _claude_profile_launch personal 3 env -u CLAUDE_CONFIG_DIR "$@" }
claude-az() { _claude_profile_launch az 2 env CLAUDE_CONFIG_DIR="$HOME/.claude-az" "$@" }
