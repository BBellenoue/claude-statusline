# Contributing

Bug reports and pull requests are welcome.

## Before you open a pull request

- `statusline.sh` and `statusline.ps1` print the same thing. Change both, or neither.
- A new behavior is a new case: add `tests/cases/<name>.json` and its expected plain output
  `tests/cases/<name>.txt`.
- Run `bash tests/run.sh`. It renders every case with both scripts, with and without `NO_COLOR`, and
  compares the result with the `.txt` file and the two scripts with each other. Without `pwsh` on your
  machine the comparison between scripts is skipped, CI runs it on Linux, macOS and Windows.
- `bash` scripts must pass `shellcheck`, the PowerShell script must pass PSScriptAnalyzer. CI checks both.
- Commit messages and the pull request text carry no AI attribution (a co-author trailer naming an
  AI, a "generated with" line). CI refuses them.
- Keep the scripts quiet: a status line that prints an error is worse than one that prints nothing.

## The screenshot

`docs/statusline.svg` is generated from the real output of the script:

```sh
node scripts/render-screenshot.mjs
```

Regenerate it when the layout or the colors change.

## Releasing

1. Move the `Unreleased` entries of `CHANGELOG.md` under a new version heading and merge.
2. Tag and publish, attaching the scripts and their checksums:

```sh
git tag vX.Y.Z && git push origin vX.Y.Z
shasum -a 256 statusline.sh statusline.ps1 > SHA256SUMS
gh release create vX.Y.Z statusline.sh statusline.ps1 SHA256SUMS --title vX.Y.Z --notes-file <notes>
```

The install commands in the README download the latest release, not `main`.

## Commits

A short English sentence in the imperative, one change per commit. Pull requests are squash-merged.
