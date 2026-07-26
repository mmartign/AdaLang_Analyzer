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

echo "CLI robustness tests passed"
