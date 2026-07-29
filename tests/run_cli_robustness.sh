#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
output=$(mktemp "${TMPDIR:-/tmp}/adalang-cli.XXXXXX")
trap 'rm -f "$output"' EXIT HUP INT TERM

"$analyzer" --version >"$output"
grep -F 'adalang-analyzer version ' "$output" >/dev/null

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

#  Repeated sources, including path aliases separated by another input, are
#  analyzed once. This prevents duplicate verbose lines and duplicate findings.
if "$analyzer" -v -checks=No_Goto \
     tests/bug_findings.adb tests/parameter_mode_clean.adb \
     ./tests/bug_findings.adb >"$output" 2>&1
then
   echo "No_Goto finding unexpectedly succeeded" >&2
   exit 1
fi
parse_count=$(grep -Fc \
  'adalang-analyzer [INFO]: Parsing: tests/bug_findings.adb' "$output")
finding_count=$(grep -Fc 'warning: goto statement used [No_Goto]' "$output")
if [ "$parse_count" -ne 1 ] || [ "$finding_count" -ne 1 ] ||
   ! grep -F 'Files scanned : 2' "$output" >/dev/null ||
   ! grep -F 'Violations    : 1' "$output" >/dev/null
then
   echo "duplicate source input was analyzed more than once" >&2
   cat "$output" >&2
   exit 1
fi

echo "CLI robustness tests passed"
