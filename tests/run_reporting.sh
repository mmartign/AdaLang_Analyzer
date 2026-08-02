#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-reporting.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

json="$work/findings.json"
sarif="$work/findings.sarif"
baseline="$work/findings.baseline"
proof_json="$work/proof.json"
clean_proof_json="$work/proof-clean.json"
automotive_json="$work/automotive.json"
automotive_sarif="$work/automotive.sarif"
automotive_config="$work/automotive.cfg"
automotive_baseline="$work/automotive.baseline"

if "$analyzer" --format=json --output="$json" \
     --write-baseline="$baseline" \
     -checks='Contradictory_Condition' tests/bug_findings.adb
then
   echo "expected the initial structured run to find a violation" >&2
   exit 1
fi

grep -F '"version": "1.0"' "$json" >/dev/null
grep -F '"ruleId": "Contradictory_Condition"' "$json" >/dev/null
grep -F '"explanation": "The two Boolean operands are structural complements' \
  "$json" >/dev/null
grep -F '"evidence": "left operand =>' "$json" >/dev/null
grep -F '"baseline": false' "$json" >/dev/null
grep -F '"proofSummary": {"scope": "enumerated outcomes in current analysis scope; not exhaustive", "total": 0' \
  "$json" >/dev/null
grep -F '"proofObligations": [' "$json" >/dev/null
grep -E '^[0-9a-f]{16}$' "$baseline" >/dev/null

#  A finding in the baseline remains in structured output for auditing, but
#  does not fail the command and is clearly identified as unchanged.
"$analyzer" --format=sarif --output="$sarif" --baseline="$baseline" \
  -checks='Contradictory_Condition' tests/bug_findings.adb

grep -F '"version": "2.1.0"' "$sarif" >/dev/null
grep -F '"ruleId": "Contradictory_Condition"' "$sarif" >/dev/null
grep -F '"baselineState": "unchanged"' "$sarif" >/dev/null
grep -F '"properties": {"explanation": "The two Boolean operands are structural complements' \
  "$sarif" >/dev/null
grep -F '"evidence": "left operand =>' "$sarif" >/dev/null
grep -F '"adalang/v1": "' "$sarif" >/dev/null

#  Automotive evidence records the selected preset and the exact effective
#  configuration after later command-line refinements. Project/scenario,
#  configuration, baseline, threshold, analyzed-file, and skipped-check
#  context make a saved report reproducible rather than relying on the preset
#  label alone.
cat >"$automotive_config" <<'EOF'
--automotive
-complexity-threshold=7
EOF
cat >"$automotive_baseline" <<'EOF'
# Empty evidence baseline
EOF
if "$analyzer" --config="$automotive_config" \
     -checks='-*,No_Runtime_Check_Suppression' \
     -Ptests/verification_differential.gpr \
     -XREPORT_MODE=automotive \
     --baseline="$automotive_baseline" \
     --format=json --output="$automotive_json" \
     tests/automotive_runtime_suppression_findings.adb
then
   echo "expected automotive metadata fixture to produce violations" >&2
   exit 1
fi
grep -F '"selectedPreset": "automotive"' "$automotive_json" >/dev/null
grep -F '"toolVersion": "0.1.0-dev"' "$automotive_json" >/dev/null
grep -F '"No_Runtime_Check_Suppression"' "$automotive_json" >/dev/null
if [ "$(grep -c '^      "[A-Za-z_]*"$' "$automotive_json")" -ne 1 ]; then
   echo "structured report did not preserve the effective enabled-rule set" >&2
   cat "$automotive_json" >&2
   exit 1
fi
grep -F '"cyclomaticComplexity": 7' "$automotive_json" >/dev/null
grep -F '"configFile": "' "$automotive_json" >/dev/null
grep -F 'automotive.cfg"' "$automotive_json" >/dev/null
grep -F 'automotive.baseline"' "$automotive_json" >/dev/null
grep -F '"tests/verification_differential.gpr"' "$automotive_json" >/dev/null
grep -F '"REPORT_MODE=automotive"' "$automotive_json" >/dev/null
grep -F '"tests/automotive_runtime_suppression_findings.adb"' \
  "$automotive_json" >/dev/null
grep -F '"skippedChecks": 0' "$automotive_json" >/dev/null

if "$analyzer" --automotive -checks='-*,No_Runtime_Check_Suppression' \
     --format=sarif --output="$automotive_sarif" \
     tests/automotive_runtime_suppression_findings.adb
then
   echo "expected automotive SARIF fixture to produce violations" >&2
   exit 1
fi
grep -F '"selectedPreset": "automotive"' "$automotive_sarif" >/dev/null
grep -F '"enabledRules": [' "$automotive_sarif" >/dev/null
grep -F '"No_Runtime_Check_Suppression"' "$automotive_sarif" >/dev/null
grep -F '"analyzedFiles": [' "$automotive_sarif" >/dev/null

#  The text interface keeps its historical diagnostic and exit behavior.
if "$analyzer" -checks='Contradictory_Condition' \
     tests/bug_findings.adb >"$work/text" 2>&1
then
   echo "expected the text run to find a violation" >&2
   exit 1
fi
grep -F '[Contradictory_Condition]' "$work/text" >/dev/null
grep -F '  why: The two Boolean operands are structural complements' \
  "$work/text" >/dev/null
grep -F '  evidence: left operand =>' "$work/text" >/dev/null

#  Every range/index operation reached by the current check machinery is
#  represented. Known failures refine to definite-error; all other outcomes
#  remain unproved because this stage makes no green proof claim.
proof_checks='Known_Range_Check_Failure,Known_Index_Check_Failure'
if "$analyzer" --format=json --output="$proof_json" \
     -checks="$proof_checks" tests/runtime_check_findings.adb
then
   echo "expected proof reporting fixture to produce violations" >&2
   exit 1
fi
grep -F \
  '"proofSummary": {"scope": "enumerated outcomes in current analysis scope; not exhaustive", "total": 12, "provedSafe": 0, "definiteError": 5, "unproved": 7, "unreachable": 0, "unsupported": 0}' \
  "$proof_json" >/dev/null
if [ "$(grep -c '"kind": "range-check"' "$proof_json")" -ne 10 ] ||
   [ "$(grep -c '"kind": "index-check"' "$proof_json")" -ne 2 ] ||
   [ "$(grep -c '"status": "definite-error"' "$proof_json")" -ne 5 ] ||
   [ "$(grep -c '"status": "unproved"' "$proof_json")" -ne 7 ] ||
   [ "$(grep -Ec '"id": "proof/v1/[0-9a-f]{16}"' "$proof_json")" -ne 12 ]
then
   echo "unexpected structured proof obligations" >&2
   cat "$proof_json" >&2
   exit 1
fi

if "$analyzer" -v -checks=Known_Assertion_Failure \
     tests/proof_assertion_findings.adb >"$work/proof-text" 2>&1
then
   echo "expected proof assertion fixture to produce violations" >&2
   exit 1
fi
grep -F \
  'Proof obligations (enumerated outcomes in current analysis scope; not exhaustive):' \
  "$work/proof-text" >/dev/null
grep -F '  Total : 3' "$work/proof-text" >/dev/null
grep -F '  definite-error : 3' "$work/proof-text" >/dev/null
grep -F '  Details:' "$work/proof-text" >/dev/null
grep -F '      method: abstract-interpretation' "$work/proof-text" >/dev/null
grep -F '      why: assertion condition is false based on the incoming state' \
  "$work/proof-text" >/dev/null
grep -F '      evidence: assertion condition => false' \
  "$work/proof-text" >/dev/null

#  Without -v the per-obligation detail lines are omitted, but the summary
#  still declares a nonzero total; a note must make that omission explicit
#  so downstream tooling parsing the text report isn't silently misled.
if "$analyzer" -checks=Known_Assertion_Failure \
     tests/proof_assertion_findings.adb >"$work/proof-text-quiet" 2>&1
then
   echo "expected proof assertion fixture to produce violations" >&2
   exit 1
fi
grep -F '  Total : 3' "$work/proof-text-quiet" >/dev/null
grep -F \
  '  (details suppressed; rerun with -v to list each proof obligation)' \
  "$work/proof-text-quiet" >/dev/null
if grep -F '  Details:' "$work/proof-text-quiet" >/dev/null; then
   echo "did not expect proof obligation details without -v" >&2
   exit 1
fi

#  A clean finding run is not presented as proved safe. Its applicable
#  assertions are visible as unproved while the command remains successful.
"$analyzer" --format=json --output="$clean_proof_json" \
  -checks=Known_Assertion_Failure tests/proof_assertion_clean.adb
grep -F \
  '"proofSummary": {"scope": "enumerated outcomes in current analysis scope; not exhaustive", "total": 2, "provedSafe": 0, "definiteError": 0, "unproved": 2, "unreachable": 0, "unsupported": 0}' \
  "$clean_proof_json" >/dev/null
grep -F '"findings": [' "$clean_proof_json" >/dev/null
if [ "$(grep -c '"kind": "assertion"' "$clean_proof_json")" -ne 2 ] ||
   [ "$(grep -c '"status": "unproved"' "$clean_proof_json")" -ne 2 ]
then
   echo "clean assertions were not exposed as unproved obligations" >&2
   cat "$clean_proof_json" >&2
   exit 1
fi

echo "structured reporting tests passed"
