#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
output=$(mktemp "${TMPDIR:-/tmp}/adalang-recommended.XXXXXX")
trap 'rm -f "$output"' EXIT HUP INT TERM

if "$analyzer" --recommended tests/bug_findings.adb >"$output" 2>&1
then
   echo "recommended preset unexpectedly missed defect findings" >&2
   exit 1
fi

for rule in Contradictory_Condition Identical_Branches Empty_Loop
do
   grep -F "[$rule]" "$output" >/dev/null || {
      echo "recommended preset omitted $rule" >&2
      cat "$output" >&2
      exit 1
   }
done

for rule in No_Goto Missing_Requirement_Trace No_Classwide_Type \
   Complete_Initialization Missing_Global_Contract
do
   if grep -F "[$rule]" "$output" >/dev/null
   then
      echo "recommended preset unexpectedly enabled policy rule $rule" >&2
      cat "$output" >&2
      exit 1
   fi
done

"$analyzer" -q --recommended tests/advanced_clean.adb

#  The self-findings reviewed while introducing this preset are either
#  path-required initialization or values consumed by nested/API operations.
"$analyzer" -q -checks=Overwritten_Assignment \
  src/adalang_analyzer-numeric_literals.adb
"$analyzer" -q -checks=Dead_Store \
  src/adalang_analyzer-flow_interp.adb \
  src/adalang_analyzer-vc_prover.adb

"$analyzer" --help >"$output"
grep -F -- '--recommended' "$output" >/dev/null

echo "recommended preset tests passed"
