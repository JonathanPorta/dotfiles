#!/usr/bin/env bash
# Claude Code status line script.
# Layout: model [fast] | e:effort | ctx% [200k warning] | 5h reset | 7d reset |
#         PR state | estimated cost | reported cost | line delta | owner/repo |
#         prrq queue rollup

input=$(cat)

# One jq pass -> fields joined by the unit separator. A non-whitespace
# delimiter is essential: whitespace IFS collapses empty fields and shifts all
# fields after an absent value (for example, an absent pull request).
IFS=$'\037' read -r \
  model model_id used_pct five_pct five_reset seven_pct seven_reset \
  fast_mode effort exceeds pr_number pr_state repo_owner repo_name cwd \
  cost_real lines_add lines_del total_in total_out \
  <<<"$(printf '%s' "$input" | jq -r '[
    .model.display_name // "unknown",
    .model.id // "",
    (.context_window.used_percentage // ""),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // ""),
    (.fast_mode // false),
    (.effort.level // ""),
    (.exceeds_200k_tokens // false),
    (.pr.number // ""),
    (.pr.review_state // ""),
    (.workspace.repo.owner // ""),
    (.workspace.repo.name // ""),
    (.workspace.current_dir // .cwd // ""),
    (.cost.total_cost_usd // ""),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0),
    (.context_window.total_input_tokens // 0),
    (.context_window.total_output_tokens // 0)
  ] | map(tostring) | join("\u001f")')"

# Leave a per-project context-pressure breadcrumb for prrq and other local
# helpers. Readers treat a missing or stale file as unknown.
sid=$(printf '%s' "$input" | jq -r '.session_id // ""')
pdir=$(printf '%s' "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // ""')
if [ -n "$used_pct" ] && [ -n "$pdir" ]; then
  proot=$(git -C "$pdir" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$pdir")
  pkey=$(printf '%s' "$proot" | { md5 -q 2>/dev/null || md5sum | cut -d' ' -f1; } | cut -c1-12)
  printf '%.0f %s %s\n' "$used_pct" "${sid:-unknown}" "$(date +%s)" \
    >"${TMPDIR:-/tmp}/claude-ctx-$pkey.breadcrumb" 2>/dev/null
fi

# Compact reset suffix: middle-dot plus days, hours, or minutes.
fmt_reset() {
  [ -n "$1" ] || return
  local now delta
  now=$(date +%s)
  delta=$(( $1 - now ))
  [ "$delta" -le 0 ] && return
  if [ "$delta" -ge 86400 ]; then
    printf '\302\267%dd' $(( delta / 86400 ))
  elif [ "$delta" -ge 3600 ]; then
    printf '\302\267%dh' $(( delta / 3600 ))
  else
    printf '\302\267%dm' $(( delta / 60 ))
  fi
}

parts=()

if [ "$fast_mode" = "true" ]; then
  parts+=("$model ⚡")
else
  parts+=("$model")
fi

[ -n "$effort" ] && parts+=("e:$effort")

if [ -n "$used_pct" ]; then
  ctxseg="ctx:$(printf '%.0f' "$used_pct")%"
  [ "$exceeds" = "true" ] && ctxseg="${ctxseg}⚠"
  parts+=("$ctxseg")
fi

[ -n "$five_pct" ] && parts+=("5h:$(printf '%.0f' "$five_pct")%$(fmt_reset "$five_reset")")
[ -n "$seven_pct" ] && parts+=("7d:$(printf '%.0f' "$seven_pct")%$(fmt_reset "$seven_reset")")

if [ -n "$pr_number" ]; then
  case "$pr_state" in
    approved)          pr_glyph=" ✓" ;;
    changes_requested) pr_glyph=" ✗" ;;
    pending)           pr_glyph=" …" ;;
    draft)             pr_glyph=" ◌" ;;
    *)                 pr_glyph="" ;;
  esac
  parts+=("PR#${pr_number}${pr_glyph}")
fi

# The first figure is a directional token-price estimate. The second, when
# provided by Claude Code, is its cumulative session cost.
case "$model_id" in
  *opus-4*|*opus-3*)                               rate_in=15; rate_out=75 ;;
  *sonnet-4*|*sonnet-3-7*|*sonnet-3-5*|*sonnet-3*) rate_in=3; rate_out=15 ;;
  *haiku-4*|*haiku-3-5*)                           rate_in=0.8; rate_out=4 ;;
  *haiku-3*)                                       rate_in=0.25; rate_out=1.25 ;;
  *)                                               rate_in=3; rate_out=15 ;;
esac
estimated_cost=$(awk -v ti="$total_in" -v to="$total_out" -v ri="$rate_in" -v ro="$rate_out" \
  'BEGIN { printf "%.3f", (ti * ri / 1000000) + (to * ro / 1000000) }')
parts+=("\$$estimated_cost")
[ -n "$cost_real" ] && parts+=("$(awk -v c="$cost_real" 'BEGIN { printf "\316\243$%.2f", c }')")

if [ "${lines_add:-0}" -gt 0 ] || [ "${lines_del:-0}" -gt 0 ]; then
  parts+=("$(printf '\316\224+%s/-%s' "$lines_add" "$lines_del")")
fi

if [ -n "$repo_owner" ] && [ -n "$repo_name" ]; then
  parts+=("$repo_owner/$repo_name")
else
  parts+=("$(basename "$cwd")")
fi

# Ask prrq to interpret its own state through the JSON summary contract added in
# prrq#45. Missing or older installations simply omit this
# optional segment; reaching into queue.json would couple this renderer to
# prrq's private storage schema all over again.
if command -v prrq >/dev/null 2>&1; then
  summary=$(prrq summary --json 2>/dev/null) || summary=""
  rollup=""
  if [ -n "$summary" ]; then
    rollup=$(printf '%s' "$summary" | jq -er '
      select(.schema_version == 1)
      | [ .counts.approved, .counts.changed, .counts.changes_requested,
          .counts.needs_review, .counts.error, .counts.gated,
          .counts.claimed, .counts.blocked ]
      | select(all(.[]; type == "number" and . >= 0 and floor == .))
      | @tsv' 2>/dev/null) || rollup=""
  fi
  if [ -n "$rollup" ]; then
    IFS=$'\t' read -r \
      queue_green queue_yellow queue_red queue_white queue_error queue_gated \
      queue_claimed queue_blocked <<<"$rollup"
    if [ $(( queue_green + queue_yellow + queue_red + queue_white + queue_error + queue_gated + queue_claimed + queue_blocked )) -gt 0 ]; then
      queue_segment="🟢 $queue_green  🟡 $queue_yellow  🔴 $queue_red  ⚪ $queue_white"
      [ "$queue_error" -gt 0 ] && queue_segment="$queue_segment  🟠 $queue_error"
      [ "$queue_gated" -gt 0 ] && queue_segment="$queue_segment  ⚠️ $queue_gated"
      [ "$queue_claimed" -gt 0 ] && queue_segment="$queue_segment  🔒 $queue_claimed"
      [ "$queue_blocked" -gt 0 ] && queue_segment="$queue_segment  🚫 $queue_blocked"
      parts+=("$queue_segment")
    fi
  fi
fi

printf '%s' "${parts[0]}"
for index in "${!parts[@]}"; do
  [ "$index" -eq 0 ] && continue
  printf ' | %s' "${parts[$index]}"
done
printf '\n'
