#!/bin/sh
set -eu

#  A source checked out on Windows ends its lines with CR LF, and the same
#  source checked out on Linux with LF alone. The analysis must not tell
#  them apart: the same findings at the same places, the same proof
#  obligations, and the same fingerprints, so that a baseline written on
#  one host holds on the other. Libadalang keeps the CR in a unit's text,
#  and Ada.Text_IO keeps it in a line it reads, except on Windows; the
#  checks that read lines themselves (Long_Line, Trailing_Whitespace,
#  Malformed_Requirement_Trace) counted it, and every fingerprint hashed
#  it.

analyzer_rel=${ANALYZER:-./bin/adalang_analyzer}
analyzer=$(cd "$(dirname "$analyzer_rel")" && pwd)/$(basename "$analyzer_rel")
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-line-ends.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir "$work/lf" "$work/crlf"

fixtures='bug_findings.adb new_checks_findings.adb do178c_findings.adb
precision_long_line_at_threshold.adb precision_long_line_over_threshold.adb
precision_trailing_whitespace_finding.adb
precision_requirement_trace_malformed_guard.adb
verification_array_records.adb verification_array_records.ads'

#  The fixtures as LF and as CR LF files, whichever way they were checked
#  out.
for fixture in $fixtures; do
   tr -d '\r' <"tests/$fixture" >"$work/lf/$fixture"
   awk '{ printf "%s\r\n", $0 }' "$work/lf/$fixture" >"$work/crlf/$fixture"
done
if ! grep "$(printf '\r')" "$work/crlf/bug_findings.adb" >/dev/null; then
   echo "could not write a fixture with CR LF line ends" >&2
   exit 1
fi

#  Every check but the compiler's, which only runs with GNAT on the path.
checks=$("$analyzer" -list-checks 2>/dev/null \
   | sed -n 's/^  \([A-Z][A-Za-z0-9_]*\) \[.*/\1/p' \
   | grep -v '^Compiler_' | paste -sd, -)

#  Each run is made from the directory of its copies, so that the reports
#  name the files the same way.
run() {
   kind=$1 name=$2
   shift 2
   (cd "$work/$kind" && "$analyzer" "$@") >"$work/$name.$kind" 2>&1 || true
}

for fixture in bug_findings.adb new_checks_findings.adb do178c_findings.adb \
   precision_long_line_at_threshold.adb precision_long_line_over_threshold.adb \
   precision_trailing_whitespace_finding.adb \
   precision_requirement_trace_malformed_guard.adb
do
   for kind in lf crlf; do
      run "$kind" "$fixture" -checks="$checks" --format=json "$fixture"
   done
   if ! cmp -s "$work/$fixture.lf" "$work/$fixture.crlf"; then
      echo "the report on $fixture depends on its line ends" >&2
      diff "$work/$fixture.lf" "$work/$fixture.crlf" >&2 || true
      exit 1
   fi
done

#  The findings that told them apart, still there.
if ! grep -F '"ruleId": "Trailing_Whitespace"' \
       "$work/precision_trailing_whitespace_finding.adb.crlf" >/dev/null \
  || ! grep -F '"ruleId": "Malformed_Requirement_Trace"' \
       "$work/precision_requirement_trace_malformed_guard.adb.crlf" \
       >/dev/null \
  || grep -F '"ruleId": "Long_Line"' \
       "$work/precision_long_line_at_threshold.adb.crlf" >/dev/null
then
   echo "a line-based check misread a file with CR LF line ends" >&2
   exit 1
fi

#  Proof obligations, their identifiers and their verdicts.
for kind in lf crlf; do
   run "$kind" verify --verify --format=json \
      verification_array_records.adb verification_array_records.ads
done
if ! cmp -s "$work/verify.lf" "$work/verify.crlf"; then
   echo "the proof obligations depend on the line ends" >&2
   diff "$work/verify.lf" "$work/verify.crlf" >&2 || true
   exit 1
fi

#  A baseline written with CR LF line ends, as on Windows, suppresses the
#  same findings.
run lf baseline -checks="$checks" --write-baseline="$work/baseline" \
   bug_findings.adb
awk '{ printf "%s\r\n", $0 }' "$work/baseline" >"$work/baseline.crlf"
run crlf rebased -q -checks="$checks" --baseline="$work/baseline.crlf" \
   bug_findings.adb
if [ -s "$work/rebased.crlf" ]; then
   echo "a CR LF baseline did not hold on a CR LF source" >&2
   cat "$work/rebased.crlf" >&2
   exit 1
fi

echo "line-end tests passed"
