# claude-statusline

A four-line status line for [Claude Code](https://code.claude.com): model, folder, git,
context window, session stats and your 5-hour / 7-day usage limits, with colored gauges.

```
🤖 Opus · high │ 📁 my-project │ 🌿 main ✚3
🧠 ctx ◼◼◼◼◼◻◻◻◻◻◻◻ 43% · 85k/200k │ +120 -34 │ ⏱ 1h13
⏳ 5h  ◼◼◼◼◼◼◼◼◻◻◻◻ 63% · 2h41
📅 7d  💀 ◼◼◼◼◼◼◼◼◼◼◻◻ 87% · 3d4h
```

Each bar runs green, yellow, red along its length (squares 1 to 6, 7 to 9, 10 to 12). The
percentage is green below 50 %, yellow below 80 %, red above, with a skull from 80 %. The two limit
lines only show up on a claude.ai subscription, once Claude Code has received its first
reply in the session.

Two scripts with identical output, pick the one your machine already runs:

| Script          | Needs            | Natural fit                          |
|-----------------|------------------|--------------------------------------|
| `statusline.sh` | bash 3.2+, `jq`  | Linux, macOS, Git Bash on Windows    |
| `statusline.ps1`| PowerShell 7+    | Windows (also runs on Linux, macOS)  |

`git` is optional: without it, or outside a repository, the branch is simply left out.

## Install

Copy the script into `~/.claude/`, then add a `statusLine` entry to
`~/.claude/settings.json`.

**Linux / macOS**

```sh
curl -fsSL https://raw.githubusercontent.com/BBellenoue/claude-statusline/main/statusline.sh -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

```json
"statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
```

`jq` comes from `brew install jq` or `sudo apt install jq`.

**Windows (PowerShell 7)**

```powershell
irm https://raw.githubusercontent.com/BBellenoue/claude-statusline/main/statusline.ps1 -OutFile ~/.claude/statusline.ps1
```

```json
"statusLine": { "type": "command", "command": "pwsh -NoProfile -File C:/Users/<you>/.claude/statusline.ps1" }
```

The status line refreshes on its own, there is nothing to restart.

## Try it without Claude Code

```sh
bash statusline.sh < test.json
pwsh -NoProfile -File statusline.ps1 < test.json
```

## License

[MIT](LICENSE)
