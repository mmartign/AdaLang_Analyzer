#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-reporting.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

json="$work/findings.json"
sarif="$work/findings.sarif"
baseline="$work/findings.baseline"

if "$analyzer" --format=json --output="$json" \
     --write-baseline="$baseline" \
     -checks='Contradictory_Condition' tests/bug_findings.adb
then
   echo "expected the initial structured run to find a violation" >&2
   exit 1
fi

grep -F '"version": "1.0"' "$json" >/dev/null
grep -F '"ruleId": "Contradictory_Condition"' "$json" >/dev/null
grep -F '"baseline": false' "$json" >/dev/null
grep -E '^[0-9a-f]{16}$' "$baseline" >/dev/null

#  A finding in the baseline remains in structured output for auditing, but
#  does not fail the command and is clearly identified as unchanged.
"$analyzer" --format=sarif --output="$sarif" --baseline="$baseline" \
  -checks='Contradictory_Condition' tests/bug_findings.adb

grep -F '"version": "2.1.0"' "$sarif" >/dev/null
grep -F '"ruleId": "Contradictory_Condition"' "$sarif" >/dev/null
grep -F '"baselineState": "unchanged"' "$sarif" >/dev/null
grep -F '"adalang/v1": "' "$sarif" >/dev/null

#  The text interface keeps its historical diagnostic and exit behavior.
if "$analyzer" -checks='Contradictory_Condition' \
     tests/bug_findings.adb >"$work/text" 2>&1
then
   echo "expected the text run to find a violation" >&2
   exit 1
fi
grep -F '[Contradictory_Condition]' "$work/text" >/dev/null

echo "structured reporting tests passed"
