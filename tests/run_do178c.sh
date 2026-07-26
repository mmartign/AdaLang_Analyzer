#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-do178c.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

trace_rules='-*,Missing_Requirement_Trace,Malformed_Requirement_Trace,Suppression_Without_Rationale'

if "$analyzer" --do178c=A -checks="$trace_rules" \
     tests/do178c_findings.adb >"$work/findings" 2>&1
then
   echo "expected DO-178C traceability findings" >&2
   exit 1
fi

for rule in \
   Missing_Requirement_Trace Malformed_Requirement_Trace \
   Suppression_Without_Rationale
do
   grep -F "[$rule]" "$work/findings" >/dev/null || {
      echo "missing DO-178C finding: $rule" >&2
      cat "$work/findings" >&2
      exit 1
   }
done

"$analyzer" -q --do178c=A -checks="$trace_rules" tests/do178c_clean.adb

#  Levels A-C enable source-to-requirement tracing. Level D deliberately does
#  not imply source-code verification objectives.
for level in A B C
do
   "$analyzer" -q --do178c="$level" tests/do178c_clean.adb
   if "$analyzer" --do178c="$level" tests/do178c_findings.adb \
        >"$work/level-$level" 2>&1
   then
      echo "DO-178C level $level unexpectedly missed traceability" >&2
      exit 1
   fi
   grep -F '[Missing_Requirement_Trace]' "$work/level-$level" >/dev/null
done

"$analyzer" -q --do178c=D tests/do178c_findings.adb

for specification in 'A:MC/DC' 'B:decision' 'C:statement' 'D:none'
do
   level=${specification%%:*}
   coverage=${specification#*:}
   json="$work/level-$level.json"
   "$analyzer" --do178c="$level" -checks='-*' \
     --format=json --output="$json" tests/do178c_clean.adb
   grep -F "\"assuranceProfile\": \"DO-178C Level $level support\"" \
     "$json" >/dev/null
   grep -F "\"structuralCoverageObjective\": \"$coverage\"" \
     "$json" >/dev/null
   grep -F \
     '"certificationClaim": "verification support only; not a compliance determination"' \
     "$json" >/dev/null
done

sarif="$work/level-A.sarif"
"$analyzer" --do178c=A -checks='-*' --format=sarif --output="$sarif" \
  tests/do178c_clean.adb
grep -F '"assuranceProfile": "DO-178C Level A support"' "$sarif" >/dev/null
grep -F '"structuralCoverageObjective": "MC/DC"' "$sarif" >/dev/null

if "$analyzer" --do178c=E tests/do178c_clean.adb >"$work/invalid" 2>&1
then
   echo "invalid DO-178C level was accepted" >&2
   exit 1
fi
grep -F "invalid DO-178C level 'E'" "$work/invalid" >/dev/null

echo "DO-178C support profile tests passed"
