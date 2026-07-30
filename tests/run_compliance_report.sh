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

#  An unsupported standard fails loudly rather than silently producing no
#  report.
if "$analyzer" --do178c=A --compliance-report=bogus \
     tests/do178c_clean.adb >"$work/invalid" 2>&1
then
   echo "unsupported compliance standard was accepted" >&2
   exit 1
fi
grep -F "unsupported compliance standard 'bogus'" "$work/invalid" >/dev/null

echo "compliance report tests passed"
