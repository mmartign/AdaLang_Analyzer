#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
output=$(mktemp "${TMPDIR:-/tmp}/adalang-cli.XXXXXX")
trap 'rm -f "$output"' EXIT HUP INT TERM

if "$analyzer" -q -checks=No_Goto tests/invalid_syntax.adb \
     >"$output" 2>&1
then
   echo "invalid Ada source unexpectedly succeeded" >&2
   exit 1
fi
grep -F 'invalid_syntax.adb:' "$output" >/dev/null

if "$analyzer" -q -checks=No_Goto tests >"$output" 2>&1
then
   echo "directory source input unexpectedly succeeded" >&2
   exit 1
fi
grep -F 'not a regular source file: tests' "$output" >/dev/null

if "$analyzer" -q -checks=No_Goto >"$output" 2>&1
then
   echo "option-only invocation unexpectedly succeeded" >&2
   exit 1
fi
grep -F 'error: no source files provided' "$output" >/dev/null

#  Identical adjacent verbose lines are emitted only once, but become visible
#  again after a different line.
"$analyzer" -v -checks=No_Goto \
  tests/automotive_state_clean.ads tests/automotive_state_clean.ads \
  tests/parameter_mode_clean.adb tests/automotive_state_clean.ads \
  >"$output" 2>&1
count=$(grep -Fc \
  'adalang-analyzer [INFO]: Parsing: tests/automotive_state_clean.ads' \
  "$output")
if [ "$count" -ne 2 ]; then
   echo "consecutive duplicate output was not suppressed" >&2
   cat "$output" >&2
   exit 1
fi

echo "CLI robustness tests passed"
