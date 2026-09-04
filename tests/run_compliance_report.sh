#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-compliance-report.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

report="$work/report.md"

#  Basic shape: objective table, suppression trail, baseline table, and the
#  unsupported-objectives section all present, with the required disclaimer.
"$analyzer" -q --do178c=A --compliance-report=do178c \
  --compliance-report-output="$report" tests/do178c_findings.adb || true

grep -F '# AdaLang Analyzer -- DO-178C compliance evidence report' \
  "$report" >/dev/null
grep -F '## Objectives' "$report" >/dev/null
grep -F '| Traceability |' "$report" >/dev/null
grep -F '## Suppression rationale trail' "$report" >/dev/null
grep -F '## Baseline-matched findings' "$report" >/dev/null
grep -F '## Objectives with no automated support' "$report" >/dev/null
grep -F 'not a compliance determination' "$report" >/dev/null
grep -F 'Tool qualification' "$report" >/dev/null

#  --compliance-report with no --compliance-report-output writes to stdout,
#  even under -q.
"$analyzer" -q --do178c=A --compliance-report=do178c tests/do178c_clean.adb \
  >"$work/stdout_report.md"
grep -F '# AdaLang Analyzer -- DO-178C compliance evidence report' \
  "$work/stdout_report.md" >/dev/null

#  An inline suppression's rationale is captured verbatim in the trail, and
#  the suppressed rule itself does not inflate the open-finding counts.
suppressed_report="$work/suppressed.md"
"$analyzer" -q --do178c=A --compliance-report=do178c \
  --compliance-report-output="$suppressed_report" \
  tests/compliance_report_suppressed.adb || true
grep -F 'fixture self-assignment' "$suppressed_report" >/dev/null
grep -F '| Self_Assignment |' "$suppressed_report" >/dev/null

#  Baseline-matched findings appear in their own table, distinct from the
#  inline suppression trail, and are called out as carrying no rationale.
baseline_file="$work/baseline.txt"
"$analyzer" -q --do178c=A --write-baseline="$baseline_file" \
  tests/do178c_findings.adb || true
baseline_report="$work/baseline_report.md"
"$analyzer" -q --do178c=A --baseline="$baseline_file" \
  --compliance-report=do178c --compliance-report-output="$baseline_report" \
  tests/do178c_findings.adb
awk '/^## Baseline-matched findings/{flag=1; next}
     /^## Objectives with no automated support/{flag=0}
     flag' "$baseline_report" | grep -F 'Missing_Requirement_Trace' >/dev/null

#  ISO 26262: same report shape, driven by --automotive instead of
#  --do178c, with its own ten-category, non-normative objective set.
iso_report="$work/iso26262.md"
"$analyzer" -q --automotive --compliance-report=iso26262 \
  --compliance-report-output="$iso_report" \
  tests/automotive_restrictions_findings.adb || true
grep -F '# AdaLang Analyzer -- ISO 26262 compliance evidence report' \
  "$iso_report" >/dev/null
grep -F '| Restricted control flow |' "$iso_report" >/dev/null
grep -F '| Deviation control |' "$iso_report" >/dev/null
grep -F 'Directive-by-directive ISO 26262 mapping' "$iso_report" >/dev/null
grep -F "No normative mapping to the licensed ISO 26262 text exists" \
  "$iso_report" >/dev/null
grep -F 'No ISO 26262-8 tool confidence level' "$iso_report" >/dev/null

#  EN 50128: same report shape and the same --automotive-driven rule set as
#  ISO 26262, under its own EN-50128-flavored objective labels.
en_report="$work/en50128.md"
"$analyzer" -q --automotive --compliance-report=en50128 \
  --compliance-report-output="$en_report" \
  tests/automotive_restrictions_findings.adb || true
grep -F '# AdaLang Analyzer -- EN 50128 compliance evidence report' \
  "$en_report" >/dev/null
grep -F '| Structured and modular programming |' "$en_report" >/dev/null
grep -F '| Deviation control |' "$en_report" >/dev/null
grep -F 'Directive-by-directive EN 50128 mapping' "$en_report" >/dev/null
grep -F "No normative mapping to the licensed EN 50128 text exists" \
  "$en_report" >/dev/null
grep -F 'Tool classification and confidence' "$en_report" >/dev/null

#  An unsupported standard fails loudly rather than silently producing no
#  report.
if "$analyzer" --do178c=A --compliance-report=bogus \
     tests/do178c_clean.adb >"$work/invalid" 2>&1
then
   echo "unsupported compliance standard was accepted" >&2
   exit 1
fi
grep -F "unsupported compliance standard 'bogus'" "$work/invalid" >/dev/null
grep -F "'en50128'" "$work/invalid" >/dev/null

#  --compliance-report-format=json: same evidence as the Markdown report
#  (objectives, suppression trail, baseline table, unsupported objectives,
#  disclaimer), as a machine-readable document instead.
json_report="$work/report.json"
"$analyzer" -q --do178c=A --compliance-report=do178c \
  --compliance-report-format=json \
  --compliance-report-output="$json_report" tests/do178c_findings.adb || true

grep -F '"version": "1.0"' "$json_report" >/dev/null
grep -F '"standard": "DO-178C"' "$json_report" >/dev/null
grep -F '"objectives": [' "$json_report" >/dev/null
grep -F '"id": "Traceability"' "$json_report" >/dev/null
grep -F '"mappedChecks": [' "$json_report" >/dev/null
grep -F '"suppressionRationaleTrail": [' "$json_report" >/dev/null
grep -F '"baselineMatchedFindings": [' "$json_report" >/dev/null
grep -F '"unsupportedObjectives": [' "$json_report" >/dev/null
grep -F '"name": "Tool qualification"' "$json_report" >/dev/null
grep -F 'not a compliance determination' "$json_report" >/dev/null

#  A JSON report is well-formed: every open brace/bracket has a matching
#  close, so a truncated or malformed emission does not slip through the
#  substring checks above unnoticed.
opens=$(grep -o '[{[]' "$json_report" | wc -l | tr -d ' ')
closes=$(grep -o '[]}]' "$json_report" | wc -l | tr -d ' ')
if [ "$opens" != "$closes" ]; then
   echo "malformed compliance JSON: $opens opening vs $closes closing brackets" >&2
   cat "$json_report" >&2
   exit 1
fi

#  The inline suppression rationale trail carries through to JSON, verbatim
#  and under the same check name as the Markdown rendering.
json_suppressed="$work/suppressed.json"
"$analyzer" -q --do178c=A --compliance-report=do178c \
  --compliance-report-format=json \
  --compliance-report-output="$json_suppressed" \
  tests/compliance_report_suppressed.adb || true
grep -F '"rationale": "fixture self-assignment"' "$json_suppressed" >/dev/null
grep -F '"check": "Self_Assignment"' "$json_suppressed" >/dev/null

#  Baseline-matched findings appear in JSON too, distinct from the
#  suppression trail.
json_baseline_report="$work/baseline_report.json"
"$analyzer" -q --do178c=A --baseline="$baseline_file" \
  --compliance-report=do178c --compliance-report-format=json \
  --compliance-report-output="$json_baseline_report" \
  tests/do178c_findings.adb
awk '/"baselineMatchedFindings": \[/{flag=1; next}
     /"unsupportedObjectives": \[/{flag=0}
     flag' "$json_baseline_report" | \
  grep -F '"check": "Missing_Requirement_Trace"' >/dev/null

#  ISO 26262 JSON shares the same shape, driven by --automotive.
json_iso_report="$work/iso26262.json"
"$analyzer" -q --automotive --compliance-report=iso26262 \
  --compliance-report-format=json \
  --compliance-report-output="$json_iso_report" \
  tests/automotive_restrictions_findings.adb || true
grep -F '"standard": "ISO 26262"' "$json_iso_report" >/dev/null
grep -F '"id": "Restricted control flow"' "$json_iso_report" >/dev/null
grep -F '"id": "Deviation control"' "$json_iso_report" >/dev/null

#  EN 50128 JSON shares the same shape, also driven by --automotive.
json_en_report="$work/en50128.json"
"$analyzer" -q --automotive --compliance-report=en50128 \
  --compliance-report-format=json \
  --compliance-report-output="$json_en_report" \
  tests/automotive_restrictions_findings.adb || true
grep -F '"standard": "EN 50128"' "$json_en_report" >/dev/null
grep -F '"id": "Structured and modular programming"' "$json_en_report" \
  >/dev/null
grep -F '"id": "Deviation control"' "$json_en_report" >/dev/null

#  An unsupported compliance report format fails loudly rather than
#  silently falling back to Markdown. SARIF is explicitly rejected: it has
#  no natural slot for this report's objective/evidence structure.
if "$analyzer" --do178c=A --compliance-report=do178c \
     --compliance-report-format=sarif \
     tests/do178c_clean.adb >"$work/invalid_format" 2>&1
then
   echo "unsupported compliance report format was accepted" >&2
   exit 1
fi
grep -F "invalid compliance report format 'sarif'" "$work/invalid_format" \
  >/dev/null

#  A --compliance-report requested with no preset/assurance level selected
#  (e.g. --do178c=<level> or --automotive omitted or mistyped) would
#  otherwise silently produce a report showing "0 open findings" on every
#  objective, indistinguishable from a genuine clean run. Both the stderr
#  warning and an inline banner inside the report itself must call this out
#  loudly, in Markdown and in JSON, so the empty report cannot pass as
#  evidence unnoticed.
empty_report="$work/empty.md"
"$analyzer" -q --compliance-report=do178c \
  --compliance-report-output="$empty_report" \
  tests/do178c_findings.adb 2>"$work/empty_stderr"
grep -F 'was written with no checks enabled' "$work/empty_stderr" >/dev/null
grep -F '**WARNING:**' "$empty_report" >/dev/null
grep -F 'Enabled checks: 0' "$empty_report" >/dev/null

#  The same run with an assurance level selected must not carry either
#  warning -- this is a false-positive guard on the check above.
if grep -F '**WARNING:**' "$report" >/dev/null
then
   echo "unexpected empty-checks warning in a report with checks enabled" >&2
   exit 1
fi

empty_json="$work/empty.json"
"$analyzer" -q --compliance-report=do178c \
  --compliance-report-format=json \
  --compliance-report-output="$empty_json" \
  tests/do178c_findings.adb 2>/dev/null || true
grep -F '"warning": "No checks are enabled for this run.' "$empty_json" \
  >/dev/null
grep -F '"enabledChecks": 0' "$empty_json" >/dev/null
grep -F '"warning": "",' "$json_report" >/dev/null

#  --compliance-report-output and --compliance-report-format only mean
#  anything paired with --compliance-report=<standard>; given without it,
#  they used to be silently ignored -- the run analyzed normally and no
#  report, and no diagnostic about the missing report, ever appeared. Both
#  must now fail the invocation instead, before any file is analyzed.
orphan_output="$work/orphan_output.txt"
if "$analyzer" --automotive --compliance-report-output="$orphan_output" \
     tests/automotive_restrictions_findings.adb \
     >"$work/orphan_output_stderr" 2>&1
then
   echo "--compliance-report-output without --compliance-report was accepted" >&2
   exit 1
fi
grep -F -e \
  "--compliance-report-output was given without --compliance-report=<standard>" \
  "$work/orphan_output_stderr" >/dev/null
if [ -e "$orphan_output" ]; then
   echo "--compliance-report-output without --compliance-report wrote a file" >&2
   exit 1
fi

if "$analyzer" --automotive --compliance-report-format=json \
     tests/automotive_restrictions_findings.adb \
     >"$work/orphan_format_stderr" 2>&1
then
   echo "--compliance-report-format without --compliance-report was accepted" >&2
   exit 1
fi
grep -F -e \
  "--compliance-report-format was given without --compliance-report=<standard>" \
  "$work/orphan_format_stderr" >/dev/null

echo "compliance report tests passed"
