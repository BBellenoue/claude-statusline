# claude-statusline

[![CI](https://github.com/BBellenoue/claude-statusline/actions/workflows/ci.yml/badge.svg)](https://github.com/BBellenoue/claude-statusline/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A four-line status line for [Claude Code](https://code.claude.com): model, folder, git,
context window, session stats and your 5-hour / 7-day usage limits, with colored gauges.

![A terminal window: a short Claude Code exchange above the four-line status line with model, folder and git branch, context window, 5-hour and 7-day usage gauges](docs/statusline.svg)

*Real output of `statusline.sh` in a mock terminal window. The project, branch, conversation and numbers are made up.*

Each bar runs green, yellow, red along its length (squares 1 to 6, 7 to 9, 10 to 12). The
percentage is green below 50 %, yellow below 80 %, red above, with a red `▲` from 80 %. Each icon is colored like what it introduces: the folder
blue, the branch green, a gauge icon in the color of its level. The two limit
lines only show up on a claude.ai subscription, once Claude Code has received its first reply in the
session. A field your Claude Code version does not send is simply left out. `NO_COLOR` is honored.

## Requirements

- Claude Code with `statusLine` command support.
- A terminal with 24-bit color and a font that has the symbols the status line draws with
  (`◼ ◆ ◑ ◔ ◷ ▦ ▲ ⌂ ⎇ ⑂`). Most terminals fall back to another font for a missing one.
- One of: bash 3.2+ with `jq`, or PowerShell 7+. `git` is optional: without it, or outside a
  repository, the branch is left out.

Two scripts with identical output, pick the one your machine already runs. CI renders the same cases
with both on Linux, macOS and Windows and compares them.

| Script          | Needs            | Natural fit                          |
|-----------------|------------------|--------------------------------------|
| `statusline.sh` | bash 3.2+, `jq`  | Linux, macOS, Git Bash on Windows    |
| `statusline.ps1`| PowerShell 7+    | Windows (also runs on Linux, macOS)  |

## Install

Download the script of the [latest release](https://github.com/BBellenoue/claude-statusline/releases/latest)
into `~/.claude/`, then add a `statusLine` entry to `~/.claude/settings.json`.

**Linux / macOS**

```sh
curl -fsSL https://github.com/BBellenoue/claude-statusline/releases/latest/download/statusline.sh -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

```json
"statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
```

`jq` comes from `brew install jq` or `sudo apt install jq`.

**Windows (PowerShell 7)**

```powershell
irm https://github.com/BBellenoue/claude-statusline/releases/latest/download/statusline.ps1 -OutFile ~/.claude/statusline.ps1
```

```json
"statusLine": { "type": "command", "command": "pwsh -NoProfile -File C:/Users/<you>/.claude/statusline.ps1" }
```

The status line refreshes on its own, there is nothing to restart. Each release lists the SHA-256 of
both scripts in `SHA256SUMS`; compare it with `shasum -a 256 ~/.claude/statusline.sh`.

## Troubleshooting

- **Nothing shows, or `claude-statusline: jq not found`**: install `jq` (see above), or use the
  PowerShell script.
- **To see what the script prints**, run it by hand on the sample input of this repository:
  `bash ~/.claude/statusline.sh < test.json`.
- **No limit lines (`◷` and `▦`)**: they need a claude.ai subscription and show up after the first reply
  of the session.
- **Icons or squares show as empty boxes**: your terminal font lacks one of the symbols listed under
  Requirements. Pick a font with wide Unicode coverage.
- **Raw escape codes, or wrong colors**: the terminal has no 24-bit color. Switch the colors off with
  `"command": "NO_COLOR=1 ~/.claude/statusline.sh"`.
- **No branch**: the folder is not a git repository, or `git` is not installed.
- **Windows**: use `statusline.sh` from Git Bash, or the PowerShell script with `pwsh`.

## Uninstall

Remove the `statusLine` entry from `~/.claude/settings.json` and delete `~/.claude/statusline.sh`
(or `statusline.ps1`).

## Develop

`bash tests/run.sh` renders every case in `tests/cases` with both scripts. See
[CONTRIBUTING.md](CONTRIBUTING.md). Report a vulnerability through [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
