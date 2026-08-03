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

#  A subtype of a scalar type from a with'd, externally defined package
#  (e.g. Interfaces.Integer_16) makes Libadalang's own property
#  implementation raise Property_Error while matching a subprogram body
#  against its separately declared spec (see known_analysis_issues.tsv,
#  FP-029). This is deterministic, not flaky: it depends on whether a real
#  GNAT toolchain ("gnatls") is on PATH, since that is what the analyzer's
#  Unit_Provider relies on (via GNATCOLL.Projects) to resolve with'd
#  runtime packages such as Interfaces at all. It fails whenever no such
#  toolchain is on PATH (this repository's own default shell has none) and
#  succeeds cleanly whenever one is -- this check tolerates either
#  outcome so it passes regardless of the invoking environment, rather
#  than assuming one or the other. The fixture's unused parameter is an
#  unrelated, genuine Unused_Parameter finding, so a nonzero exit status
#  here is expected; what this checks is that the run always completes
#  and reports it, whether or not the affected checks were skipped and
#  logged along the way.
"$analyzer" -v --recommended \
     tests/external_subtype_signature_match_robustness.adb >"$output" 2>&1 || true
if ! grep -F 'Files scanned : 1' "$output" >/dev/null \
   || ! grep -F 'Unused_Parameter' "$output" >/dev/null
then
   echo "external-subtype signature-match case did not degrade gracefully" >&2
   cat "$output" >&2
   exit 1
fi

echo "CLI robustness tests passed"
