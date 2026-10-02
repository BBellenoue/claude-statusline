#!/usr/bin/env bash
# Renders every case with both scripts. The plain output must match the golden file
# next to the case, and the two scripts must agree, with and without NO_COLOR.
set -u
cd "$(dirname "$0")/.." || exit 1

fail=0
norm() { sed -E 's/[0-9]+d[0-9]+h/RESET/g'; }
have_pwsh=1
command -v pwsh >/dev/null 2>&1 || { have_pwsh=0; echo 'pwsh not found: parity not checked'; }

for f in tests/cases/*.json; do
  name=$(basename "$f" .json)
  for mode in color plain; do
    if [[ $mode == plain ]]; then export NO_COLOR=1; else unset NO_COLOR; fi
    sh_out=$(bash statusline.sh < "$f" | norm)
    if [[ $mode == plain ]]; then
      if [[ $sh_out == *$'\e'* ]]; then echo "FAIL $name: escape sequence under NO_COLOR"; fail=1; fi
      expected=$(cat "tests/cases/$name.txt")
      if [[ $sh_out != "$expected" ]]; then
        echo "FAIL $name: statusline.sh differs from tests/cases/$name.txt"
        diff <(printf '%s\n' "$expected") <(printf '%s\n' "$sh_out")
        fail=1
      fi
    fi
    if ((have_pwsh)); then
      ps_out=$(pwsh -NoProfile -File statusline.ps1 < "$f" | norm)
      if [[ $ps_out != "$sh_out" ]]; then
        echo "FAIL $name ($mode): statusline.ps1 differs from statusline.sh"
        diff <(printf '%s\n' "$sh_out") <(printf '%s\n' "$ps_out")
        fail=1
      fi
    fi
  done
done
unset NO_COLOR

out=$(PATH=/nonexistent "$(command -v bash)" statusline.sh <<<'{}')
[[ $out == *'jq not found'* ]] || { echo 'FAIL: no hint when jq is missing'; fail=1; }

exit $fail
