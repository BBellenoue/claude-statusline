# Security policy

## Supported versions

The latest release. Older versions are not patched.

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's private reporting:
<https://github.com/BBellenoue/claude-statusline/security/advisories/new>

Say what you ran, what you expected and what happened. This is a one-person project: expect an answer
within a week or so, and a fix as soon as the report is confirmed.

## What the scripts do

Each refresh, Claude Code runs the script and pipes a JSON document to its standard input. The script
reads that JSON, prints text, and runs read-only git commands (`rev-parse`, `symbolic-ref`, `status`)
in the working folder. It makes no network call and writes no file.

Git is started with `core.fsmonitor` disabled, so a repository you open cannot run a command through
its own configuration when the status line reads its state.
