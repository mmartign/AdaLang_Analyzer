#!/bin/sh
set -eu

output=$(mktemp "${TMPDIR:-/tmp}/adalang-recoverable.XXXXXX")
trap 'rm -f "$output"' EXIT HUP INT TERM

alr exec -- gprbuild -q -P tests/recoverable_diagnostic.gpr
./bin/recoverable_diagnostic_test >"$output" 2>&1

grep -F 'recoverable diagnostic test passed' "$output" >/dev/null
grep -F 'rule=Test_Rule' "$output" >/dev/null
grep -F 'operation=exercise diagnostic' "$output" >/dev/null
grep -F 'source=test_input.adb' "$output" >/dev/null
grep -F 'fallback=conservative' "$output" >/dev/null
grep -F 'exception=CONSTRAINT_ERROR: deliberate recoverable failure' \
  "$output" >/dev/null

count=$(grep -Fc 'recoverable analysis failure' "$output")
if [ "$count" -ne 1 ]
then
   echo "expected one deduplicated recoverable warning, found $count" >&2
   cat "$output" >&2
   exit 1
fi

echo "recoverable diagnostic tests passed"
