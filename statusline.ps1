# Claude Code status line, 4 lines (inspired by @dembstech, Level Up ep. 07)
#   1. model . effort | current dir | git branch (+changed files) | worktree
#   2. context used   [bar] % . tokens / size | session lines +/- | session duration
#   3. 5-hour limit   [bar] % . resets in
#   4. 7-day limit    [bar] % . resets in
# Bar cells: 1-6 green, 7-9 yellow, 10-12 red. Percentage: green < 50 %, yellow < 80 %, red above (+ skull).
# Lines 3 and 4 only appear once Claude Code sends rate_limits (claude.ai subscription, after the 1st reply).
# Requires PowerShell 7+ (Windows, Linux, macOS).

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$RawInput = [Console]::In.ReadToEnd()
$Data = $null
try { $Data = $RawInput | ConvertFrom-Json } catch { }

$Esc = [char]27
$Reset = "$Esc[0m"
$Dim = "$Esc[2m"
$Dot = [char]0x00B7
$Cross = [char]0x271A
function Emoji([int]$cp) { [char]::ConvertFromUtf32($cp) }
$IcoModel = Emoji 0x1F916   # robot
$IcoDir = Emoji 0x1F4C1     # folder
$IcoGit = Emoji 0x1F33F     # herb
$IcoCtx = Emoji 0x1F9E0     # brain
$IcoFive = Emoji 0x23F3     # hourglass
$IcoWeek = Emoji 0x1F4C5    # calendar
$IcoSkull = Emoji 0x1F480   # skull
$IcoTree = Emoji 0x1F333    # tree (worktree)
$IcoTime = Emoji 0x23F1     # stopwatch
$Sep = " $Esc[90m$([char]0x2502)$Reset "

function Tok($n) { if ($n -ge 1e6) { '{0:0.#}M' -f ($n / 1e6) } elseif ($n -ge 1e3) { '{0:0}k' -f ($n / 1e3) } else { "$n" } }

# Bar of squares (U+25A0) set apart by a space: filled cells green, yellow, red by position, empty ones navy
function Gauge([string]$Icon, [string]$Label, $Pct, $ResetsAt) {
    $P = [math]::Max(0, [math]::Min(100, [math]::Round([double]$Pct)))
    $Rgb = if ($P -ge 80) { '229;83;75' } elseif ($P -ge 50) { '230;180;60' } else { '63;185;122' }
    $Color = "$Esc[38;2;${Rgb}m"
    $Width = 12
    $Filled = [math]::Round($P / 100 * $Width)
    if ($P -gt 0 -and $Filled -eq 0) { $Filled = 1 }
    $Sq = [string][char]0x25A0
    $Bar = ''
    $Prev = ''
    for ($i = 0; $i -lt $Width; $i++) {
        $Cell = if ($i -ge $Filled) { '43;58;85' } elseif ($i -lt 6) { '63;185;122' } elseif ($i -lt 9) { '230;180;60' } else { '229;83;75' }
        if ($i -gt 0) { $Bar += ' ' }
        if ($Cell -ne $Prev) { $Bar += "$Esc[38;2;${Cell}m"; $Prev = $Cell }
        $Bar += $Sq
    }
    $Bar += $Reset
    $Skull = if ($P -ge 80) { "$IcoSkull " } else { '' }
    $Line = "$Icon $($Label.PadRight(3)) $Skull$Bar $Color$P%$Reset"
    if ($ResetsAt) {
        $Left = [DateTimeOffset]::FromUnixTimeSeconds([long]$ResetsAt) - [DateTimeOffset]::UtcNow
        if ($Left.TotalSeconds -gt 0) {
            $Txt = if ($Left.TotalHours -ge 24) { "{0}d{1}h" -f [int][math]::Floor($Left.TotalDays), $Left.Hours }
                   else { "{0}h{1:00}" -f [int][math]::Floor($Left.TotalHours), $Left.Minutes }
            $Line += " $Dim$Dot $Txt$Reset"
        }
    }
    $Line
}

# Line 1: model . effort | dir | branch | worktree
$Parts = @()
if ($Data.model.display_name) {
    $Model = "$IcoModel $Esc[1m$($Data.model.display_name)$Reset"
    if ($Data.effort.level) { $Model += " $Dim$Dot$Reset $Esc[35m$($Data.effort.level)$Reset" }
    $Parts += $Model
}

$Dir = if ($Data.workspace.current_dir) { $Data.workspace.current_dir } else { $Data.cwd }
if ($Dir) {
    $Leaf = Split-Path -Path $Dir -Leaf
    if (-not $Leaf) { $Leaf = $Dir }
    $Parts += "$IcoDir $Esc[38;2;97;175;239m$Leaf$Reset"

    $Branch = git -C "$Dir" --no-optional-locks rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { $Branch = git -C "$Dir" --no-optional-locks symbolic-ref --short HEAD 2>$null }
    if ($LASTEXITCODE -eq 0 -and $Branch) {
        $Label = $Branch.Trim()
        $ChangedCount = (git -C "$Dir" --no-optional-locks status --porcelain 2>$null | Where-Object { $_ -ne '' } | Measure-Object).Count
        if ($ChangedCount -gt 0) { $Label = "$Label $Cross$ChangedCount" }
        $Parts += "$IcoGit $Esc[32m$Label$Reset"
    }
}

$Tree = if ($Data.worktree.name) { $Data.worktree.name } else { $Data.workspace.git_worktree }
if ($Tree) { $Parts += "$IcoTree $Esc[36m$Tree$Reset" }

$Lines = @($Parts -join $Sep)

# Line 2: context gauge + tokens | lines changed | duration
$Cw = $Data.context_window
if ($null -ne $Cw.used_percentage) {
    $Ctx = Gauge $IcoCtx 'ctx' $Cw.used_percentage $null
    if ($Cw.total_input_tokens -and $Cw.context_window_size) { $Ctx += " $Dim$Dot $(Tok $Cw.total_input_tokens)/$(Tok $Cw.context_window_size)$Reset" }
    $Extra = @($Ctx)
    $Cost = $Data.cost
    if ($Cost.total_lines_added -or $Cost.total_lines_removed) {
        $Extra += "$Esc[32m+$([int]$Cost.total_lines_added)$Reset $Esc[31m-$([int]$Cost.total_lines_removed)$Reset"
    }
    if ($Cost.total_duration_ms) {
        $D = [TimeSpan]::FromMilliseconds($Cost.total_duration_ms)
        $Extra += "$IcoTime " + $(if ($D.TotalHours -ge 1) { '{0}h{1:00}' -f [int][math]::Floor($D.TotalHours), $D.Minutes } else { '{0}m' -f [int][math]::Floor($D.TotalMinutes) })
    }
    $Lines += $Extra -join $Sep
}

# Lines 3 and 4: usage limits
$Rl = $Data.rate_limits
if ($null -ne $Rl.five_hour.used_percentage) { $Lines += Gauge $IcoFive '5h' $Rl.five_hour.used_percentage $Rl.five_hour.resets_at }
if ($null -ne $Rl.seven_day.used_percentage) { $Lines += Gauge $IcoWeek '7d' $Rl.seven_day.used_percentage $Rl.seven_day.resets_at }

[Console]::Write($Lines -join "`n")
