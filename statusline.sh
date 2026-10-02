#!/usr/bin/env bash
# Claude Code status line, 4 lines - bash + jq port of statusline.ps1, same output.
#   1. model . effort | current dir | git branch (+changed files) | worktree
#   2. context used   [bar] % . tokens / size | session lines +/- | session duration
#   3. 5-hour limit   [bar] % . resets in
#   4. 7-day limit    [bar] % . resets in
# Requires bash 3.2+ and jq (Linux, macOS, Git Bash on Windows).

E=$'\e'; R="$E[0m"; DIM="$E[2m"; DOT='·'
SEP=" $E[90m│$R "

# One jq pass: every field becomes a shell variable, empty when absent.
eval "$(jq -r '
  def tok: if . >= 1e6 then "\((. / 1e5 | round) / 10)M" elif . >= 1e3 then "\(. / 1e3 | round)k" else "\(.)" end;
  def opt(f): if . == null then "" else f end;
  @sh "model=\(.model.display_name // "")",
  @sh "effort=\(.effort.level // "")",
  @sh "dir=\(.workspace.current_dir // .cwd // "")",
  @sh "tree=\(.worktree.name // .workspace.git_worktree // "")",
  @sh "ctx=\(.context_window.used_percentage | opt(round))",
  @sh "tokens=\(if .context_window.total_input_tokens and .context_window.context_window_size
                then "\(.context_window.total_input_tokens | tok)/\(.context_window.context_window_size | tok)" else "" end)",
  @sh "added=\(.cost.total_lines_added // 0 | floor)",
  @sh "removed=\(.cost.total_lines_removed // 0 | floor)",
  @sh "mins=\(.cost.total_duration_ms | opt(. / 60000 | floor))",
  @sh "five=\(.rate_limits.five_hour.used_percentage | opt(round))",
  @sh "five_left=\(.rate_limits.five_hour.resets_at | opt(. - now | floor))",
  @sh "week=\(.rate_limits.seven_day.used_percentage | opt(round))",
  @sh "week_left=\(.rate_limits.seven_day.resets_at | opt(. - now | floor))"
' 2>/dev/null)"

# gauge ICON LABEL PCT [SECONDS_LEFT]
gauge() {
  local p=$3 left=$4 rgb filled bar="" i line
  ((p < 0)) && p=0; ((p > 100)) && p=100
  if ((p >= 80)); then rgb='229;83;75'; elif ((p >= 50)); then rgb='230;180;60'; else rgb='63;185;122'; fi
  filled=$(( (p * 12 + 50) / 100 )); ((p > 0 && filled == 0)) && filled=1
  bar="$E[38;2;${rgb}m"
  for ((i = 0; i < 12; i++)); do ((i == filled)) && bar+="$E[38;2;43;58;85m"; bar+='■'; done
  line="$1 $(printf '%-3s' "$2") $( ((p >= 80)) && printf '💀 ')$bar$R $E[38;2;${rgb}m$p%$R"
  if [[ -n $left ]] && ((left > 0)); then
    if ((left >= 86400)); then line+=" $DIM$DOT $((left / 86400))d$((left % 86400 / 3600))h$R"
    else line+=" $DIM$DOT $(printf '%dh%02d' $((left / 3600)) $((left % 3600 / 60)))$R"; fi
  fi
  printf '%s' "$line"
}

join() { local IFS=$'\x1f' out; out="$*"; printf '%s' "${out//$'\x1f'/$SEP}"; }

# Line 1: model . effort | dir | branch | worktree
parts=()
if [[ -n $model ]]; then
  m="🤖 $E[1m$model$R"
  [[ -n $effort ]] && m+=" $DIM$DOT$R $E[35m$effort$R"
  parts+=("$m")
fi
if [[ -n $dir ]]; then
  leaf=${dir//\\//}; leaf=${leaf%/}; leaf=${leaf##*/}
  parts+=("📁 $E[34m${leaf:-$dir}$R")
  if branch=$(git -C "$dir" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null) && [[ -n $branch ]]; then
    changed=$(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null | grep -c .)
    ((changed > 0)) && branch+=" ✚$changed"
    parts+=("🌿 $E[32m$branch$R")
  fi
fi
[[ -n $tree ]] && parts+=("🌳 $E[36m$tree$R")
lines=("$(join "${parts[@]}")")

# Line 2: context gauge + tokens | lines changed | duration
if [[ -n $ctx ]]; then
  c=$(gauge 🧠 ctx "$ctx")
  [[ -n $tokens ]] && c+=" $DIM$DOT $tokens$R"
  extra=("$c")
  ((added || removed)) && extra+=("$E[32m+$added$R $E[31m-$removed$R")
  if [[ -n $mins ]]; then
    if ((mins >= 60)); then extra+=("⏱ $(printf '%dh%02d' $((mins / 60)) $((mins % 60)))"); else extra+=("⏱ ${mins}m"); fi
  fi
  lines+=("$(join "${extra[@]}")")
fi

# Lines 3 and 4: usage limits
[[ -n $five ]] && lines+=("$(gauge ⏳ 5h "$five" "$five_left")")
[[ -n $week ]] && lines+=("$(gauge 📅 7d "$week" "$week_left")")

out=$(printf '%s\n' "${lines[@]}")
printf '%s' "$out"
