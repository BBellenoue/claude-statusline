# Claude Code status line, 4 lines
#   1. model . effort | current dir | git branch (+changed files) | worktree
#   2. context used   [bar] % . tokens / size | session lines +/- | session duration
#   3. 5-hour limit   [bar] % . resets in
#   4. 7-day limit    [bar] % . resets in
# Bar cells: 1-6 green, 7-9 yellow, 10-12 red. Percentage: green < 50 %, yellow < 80 %, red above (+ alert mark).
# Lines 3 and 4 only appear once Claude Code sends rate_limits (claude.ai subscription, after the 1st reply).
# Requires PowerShell 7+ (Windows, Linux, macOS).

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$RawInput = [Console]::In.ReadToEnd()
$Data = $null
try { $Data = $RawInput | ConvertFrom-Json } catch { $Data = $null }

$Esc = [char]27
$Reset = "$Esc[0m"
$Dim = "$Esc[2m"
$Dot = [char]0x00B7
$Cross = [char]0x271A
$IcoModel = [char]0x25C6    # diamond
$IcoDir = [char]0x2302      # house
$IcoGit = [char]0x2387      # branch
$IcoCtx = [char]0x25D1      # half disc
$IcoFive = [char]0x25F7     # clock face
$IcoWeek = [char]0x25A6     # grid
$IcoAlert = [char]0x25B2    # triangle
$IcoTree = [char]0x2442     # fork (worktree)
$IcoTime = [char]0x25D4     # quarter disc
$Sep = " $Esc[90m$([char]0x2502)$Reset "

$Inv = [cultureinfo]::InvariantCulture
function RoundHalfUp([double]$N) { [math]::Round($N, [MidpointRounding]::AwayFromZero) }
function Tok($n) {
    $n = [double]$n
    if ($n -ge 1e6) { ((RoundHalfUp ($n / 1e5)) / 10).ToString('0.#', $Inv) + 'M' }
    elseif ($n -ge 1e3) { (RoundHalfUp ($n / 1e3)).ToString($Inv) + 'k' }
    else { $n.ToString($Inv) }
}

# Bar of medium squares (U+25FC): filled cells green, yellow, red by position, empty ones navy
function Gauge([string]$Icon, [string]$Label, $Pct, $ResetsAt) {
    $P = [math]::Max(0, [math]::Min(100, (RoundHalfUp ([double]$Pct))))
    $Rgb = if ($P -ge 80) { '229;83;75' } elseif ($P -ge 50) { '230;180;60' } else { '63;185;122' }
    $Color = "$Esc[38;2;${Rgb}m"
    $Width = 12
    $Filled = [int][math]::Floor(($P * $Width + 50) / 100)
    if ($P -gt 0 -and $Filled -eq 0) { $Filled = 1 }
    $Sq = [string][char]0x25FC
    $Bar = ''
    $Prev = ''
    for ($i = 0; $i -lt $Width; $i++) {
        $Cell = if ($i -ge $Filled) { '43;58;85' } elseif ($i -lt 6) { '63;185;122' } elseif ($i -lt 9) { '230;180;60' } else { '229;83;75' }
        if ($Cell -ne $Prev) { $Bar += "$Esc[38;2;${Cell}m"; $Prev = $Cell }
        $Bar += $Sq
    }
    $Bar += $Reset
    $Alert = if ($P -ge 80) { "$Color$IcoAlert$Reset " } else { '' }
    $Line = "$Icon $($Label.PadRight(3)) $Alert$Bar $Color$P%$Reset"
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

    $Git = @('-c', 'core.fsmonitor=false', '-C', $Dir, '--no-optional-locks')
    $Branch = git @Git rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { $Branch = git @Git symbolic-ref --short HEAD 2>$null }
    if ($LASTEXITCODE -eq 0 -and $Branch) {
        $Label = $Branch.Trim()
        $ChangedCount = (git @Git status --porcelain 2>$null | Where-Object { $_ -ne '' } | Measure-Object).Count
        if ($ChangedCount -gt 0) { $Label = "$Label $Cross$ChangedCount" }
        $Parts += "$IcoGit $Esc[32m$Label$Reset"
    }
}

$Tree = if ($Data.worktree.name) { $Data.worktree.name } else { $Data.workspace.git_worktree }
if ($Tree) { $Parts += "$IcoTree $Esc[36m$Tree$Reset" }

$Lines = @()
if ($Parts.Count -gt 0) { $Lines += $Parts -join $Sep }

# Line 2: context gauge + tokens | lines changed | duration
$Cw = $Data.context_window
if ($null -ne $Cw.used_percentage) {
    $Ctx = Gauge $IcoCtx 'ctx' $Cw.used_percentage $null
    if ($null -ne $Cw.total_input_tokens -and $null -ne $Cw.context_window_size) { $Ctx += " $Dim$Dot $(Tok $Cw.total_input_tokens)/$(Tok $Cw.context_window_size)$Reset" }
    $Extra = @($Ctx)
    $Cost = $Data.cost
    $Added = [int][math]::Floor([double]($Cost.total_lines_added ?? 0))
    $Removed = [int][math]::Floor([double]($Cost.total_lines_removed ?? 0))
    if ($Added -or $Removed) {
        $Extra += "$Esc[32m+$Added$Reset $Esc[31m-$Removed$Reset"
    }
    if ($null -ne $Cost.total_duration_ms) {
        $Mins = [int][math]::Floor([double]$Cost.total_duration_ms / 60000)
        $Extra += "$IcoTime " + $(if ($Mins -ge 60) { '{0}h{1:00}' -f [int][math]::Floor($Mins / 60), ($Mins % 60) } else { "${Mins}m" })
    }
    $Lines += $Extra -join $Sep
}

# Lines 3 and 4: usage limits
$Rl = $Data.rate_limits
if ($null -ne $Rl.five_hour.used_percentage) { $Lines += Gauge $IcoFive '5h' $Rl.five_hour.used_percentage $Rl.five_hour.resets_at }
if ($null -ne $Rl.seven_day.used_percentage) { $Lines += Gauge $IcoWeek '7d' $Rl.seven_day.used_percentage $Rl.seven_day.resets_at }

$Out = $Lines -join "`n"
if ($env:NO_COLOR) { $Out = $Out -replace "$Esc\[[0-9;]*m", '' }
[Console]::Write($Out)
