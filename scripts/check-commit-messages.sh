#!/usr/bin/env bash
# Reads commit messages, or a pull request title and body, on stdin.
# Fails when one carries an AI attribution: a co-author trailer or a "generated with" line.
if grep -n -i -E '^co-authored-by:.*(claude|anthropic)|noreply@anthropic\.com|generated with .*claude'; then
  echo 'AI attribution found: remove it from the commit message or the pull request text.' >&2
  exit 1
fi
