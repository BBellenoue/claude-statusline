#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables are assigned by the jq eval below
# Claude Code status line, 4 lines - bash + jq port of statusline.ps1, same output.
#   1. model . effort | current dir | git branch (+changed files) | worktree
#   2. context used   [bar] % . tokens / size | session lines +/- | session duration
#   3. 5-hour limit   [bar] % . resets in
#   4. 7-day limit    [bar] % . resets in
# Requires bash 3.2+ and jq (Linux, macOS, Git Bash on Windows).

command -v jq >/dev/null 2>&1 || { printf 'claude-statusline: jq not found (https://jqlang.github.io/jq/)'; exit 0; }

shopt -s extglob

E=$'\e'; R="${E}[0m"; DIM="${E}[2m"; DOT='·'
SEP=" ${E}[90m│$R "

# One jq pass: every field becomes a shell variable, empty when absent or unusable.
eval "$(jq -r '
  def tok: if . >= 1e6 then "\((. / 1e5 | round) / 10)M" elif . >= 1e3 then "\(. / 1e3 | round)k" else "\(.)" end;
  def n: try tonumber catch null;
  def opt(f): if . == null then "" else f end;
  def first_set: map(select(. != null and . != "")) | .[0] // "";
  def v(k; f): try (k + "=" + (f | @sh)) catch "";
  v("model"; .model.display_name // ""),
  v("effort"; .effort.level // ""),
  v("dir"; [.workspace.current_dir, .cwd] | first_set),
  v("tree"; [.worktree.name, .workspace.git_worktree] | first_set),
  v("ctx"; .context_window.used_percentage | n | opt(round)),
  v("tokens"; (.context_window.total_input_tokens | n) as $u | (.context_window.context_window_size | n) as $z
              | if $u != null and $z != null then "\($u | tok)/\($z | tok)" else "" end),
  v("added"; (.cost.total_lines_added | n) // 0 | floor),
  v("removed"; (.cost.total_lines_removed | n) // 0 | floor),
  v("mins"; .cost.total_duration_ms | n | opt(. / 60000 | floor)),
  v("five"; .rate_limits.five_hour.used_percentage | n | opt(round)),
  v("five_left"; .rate_limits.five_hour.resets_at | n | opt(. - now | floor)),
  v("week"; .rate_limits.seven_day.used_percentage | n | opt(round)),
  v("week_left"; .rate_limits.seven_day.resets_at | n | opt(. - now | floor))
' 2>/dev/null)"

# gauge ICON LABEL PCT [SECONDS_LEFT]
gauge() {
  local p=$3 left=$4 rgb filled bar="" i line cell prev=""
  ((p < 0)) && p=0; ((p > 100)) && p=100
  if ((p >= 80)); then rgb='229;83;75'; elif ((p >= 50)); then rgb='230;180;60'; else rgb='63;185;122'; fi
  filled=$(( (p * 12 + 50) / 100 )); ((p > 0 && filled == 0)) && filled=1
  for ((i = 0; i < 12; i++)); do
    if ((i >= filled)); then cell='43;58;85'; elif ((i < 6)); then cell='63;185;122'; elif ((i < 9)); then cell='230;180;60'; else cell='229;83;75'; fi
    if [[ $cell != "$prev" ]]; then bar+="${E}[38;2;${cell}m"; prev=$cell; fi
    bar+='◼'
  done
  line="${E}[38;2;${rgb}m$1$R $(printf '%-3s' "$2") $( ((p >= 80)) && printf '%s▲%s ' "${E}[38;2;${rgb}m" "$R")$bar$R ${E}[38;2;${rgb}m$p%$R"
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
  m="${E}[35m◆$R ${E}[1m$model$R"
  [[ -n $effort ]] && m+=" $DIM$DOT$R ${E}[35m$effort$R"
  parts+=("$m")
fi
if [[ -n $dir ]]; then
  leaf=${dir//\\//}; leaf=${leaf%/}; leaf=${leaf##*/}
  parts+=("${E}[38;2;97;175;239m⌂ ${leaf:-$dir}$R")
  git=(git -c core.fsmonitor=false -C "$dir" --no-optional-locks)
  branch=$("${git[@]}" rev-parse --abbrev-ref HEAD 2>/dev/null) ||
    branch=$("${git[@]}" symbolic-ref --short HEAD 2>/dev/null)
  if [[ -n $branch ]]; then
    changed=$("${git[@]}" status --porcelain 2>/dev/null | grep -c .)
    ((changed > 0)) && branch+=" ✚$changed"
    parts+=("${E}[32m⎇ $branch$R")
  fi
fi
[[ -n $tree ]] && parts+=("${E}[36m⑂ $tree$R")
lines=()
((${#parts[@]})) && lines+=("$(join "${parts[@]}")")

# Line 2: context gauge + tokens | lines changed | duration
if [[ -n $ctx ]]; then
  c=$(gauge ◑ ctx "$ctx")
  [[ -n $tokens ]] && c+=" $DIM$DOT $tokens$R"
  extra=("$c")
  ((added || removed)) && extra+=("${E}[32m+$added$R ${E}[31m-$removed$R")
  if [[ -n $mins ]]; then
    if ((mins >= 60)); then extra+=("◔ $(printf '%dh%02d' $((mins / 60)) $((mins % 60)))"); else extra+=("◔ ${mins}m"); fi
  fi
  lines+=("$(join "${extra[@]}")")
fi

# Lines 3 and 4: usage limits
[[ -n $five ]] && lines+=("$(gauge ◷ 5h "$five" "$five_left")")
[[ -n $week ]] && lines+=("$(gauge ▦ 7d "$week" "$week_left")")

out=$(printf '%s\n' "${lines[@]}")
[[ -n ${NO_COLOR:-} ]] && out=${out//$'\e'\[*([0-9;])m/}
printf '%s' "$out"
