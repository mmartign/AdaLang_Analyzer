#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
checks='Contradictory_Condition,Identical_Branches,Repeated_Statement,Ineffective_Operation,Constant_Result_Operation,Empty_Loop,Unreachable_Code'
output=$(mktemp "${TMPDIR:-/tmp}/adalang-findings.XXXXXX")
trap 'rm -f "$output"' EXIT HUP INT TERM

if "$analyzer" -checks="$checks" tests/bug_findings.adb >"$output" 2>&1; then
   echo "expected bug_findings.adb to produce violations" >&2
   exit 1
fi

for rule in \
   Contradictory_Condition \
   Identical_Branches \
   Repeated_Statement \
   Ineffective_Operation \
   Constant_Result_Operation \
   Empty_Loop \
   Unreachable_Code
do
   if ! grep -F "[$rule]" "$output" >/dev/null; then
      echo "missing expected finding: $rule" >&2
      exit 1
   fi
done

if ! "$analyzer" -q -checks="$checks" tests/clean_findings.adb; then
   echo "clean_findings.adb unexpectedly produced a violation" >&2
   exit 1
fi

echo "bug-finding regression tests passed"
