# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [SemVer](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-10-02

### Added
- Four-line status line for Claude Code: model and effort, folder, git branch and changed files,
  worktree, context window, session lines and duration, 5-hour and 7-day usage limits.
- Two scripts with the same output: `statusline.sh` (bash 3.2+, `jq`) and `statusline.ps1` (PowerShell 7+).
- Bars of 12 medium squares colored by position (green, yellow, red) with the percentage colored by
  level and a skull from 80 %.
- `NO_COLOR` support.
- Tests: 18 cases rendered with both scripts and compared with golden files, PSScriptAnalyzer,
  ShellCheck, and a check that a repository's `core.fsmonitor` hook is never run.

### Fixed
- The branch is shown in a repository that has no commit yet.
- A mistyped field only drops itself, not the fields after it.
- PowerShell rounds, formats numbers and shows zero values like bash.
- `statusline.sh` reports a missing `jq` instead of printing nothing.

[Unreleased]: https://github.com/BBellenoue/claude-statusline/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/BBellenoue/claude-statusline/releases/tag/v0.1.0
