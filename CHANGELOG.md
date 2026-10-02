# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [SemVer](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-10-02

### Added
- Four-line status line for Claude Code: model and effort, folder, git branch and changed files,
  worktree, context window, session lines and duration, 5-hour and 7-day usage limits.
- Two scripts with the same output: `statusline.sh` (bash 3.2+, `jq`) and `statusline.ps1` (PowerShell 7+).
- Monochrome technical icons that take the color of the text.
- Bars of 12 medium squares colored by position (green, yellow, red). The percentage is colored by
  level and a red `▲` marks 80 % and above.
- `NO_COLOR` support.
- Tests: 18 cases rendered with both scripts and compared with golden files, ShellCheck,
  PSScriptAnalyzer, a check that a repository's `core.fsmonitor` hook is never run, and a check that
  commit messages and pull request text carry no AI attribution.

[Unreleased]: https://github.com/BBellenoue/claude-statusline/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/BBellenoue/claude-statusline/releases/tag/v1.0.0
