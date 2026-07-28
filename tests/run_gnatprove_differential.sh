#!/bin/sh
set -eu

gnatprove=${GNATPROVE:-}
if [ -z "$gnatprove" ]; then
   gnatprove=$(command -v gnatprove || true)
fi
if [ -z "$gnatprove" ] && [ -x "${HOME}/.alire/bin/gnatprove" ]; then
   gnatprove="${HOME}/.alire/bin/gnatprove"
fi

if [ -z "$gnatprove" ]; then
   echo "GNATprove differential tests skipped (gnatprove not found)"
   exit 0
fi

analyzer=${ANALYZER:-./bin/adalang_analyzer}
results=$(mktemp "${TMPDIR:-/tmp}/adalang-gnatprove-diff.XXXXXX")
gnatprove_log=$(mktemp "${TMPDIR:-/tmp}/gnatprove-diff.XXXXXX")
broken_results=$(mktemp "${TMPDIR:-/tmp}/adalang-gnatprove-diff-broken.XXXXXX")
broken_gnatprove_log=$(mktemp "${TMPDIR:-/tmp}/gnatprove-diff-broken.XXXXXX")
trap 'rm -f "$results" "$gnatprove_log" "$broken_results" "$broken_gnatprove_log"' \
  EXIT HUP INT TERM

status=0
"$analyzer" --verify -q --format=json --output="$results" \
  tests/verification_clean.adb \
  tests/verification_loop_clean.adb \
  tests/verification_call_clean.adb \
  tests/verification_vc_clean.adb \
  tests/verification_vc_contracts.adb \
  tests/verification_symbolic_assignment.adb \
  tests/verification_symbolic_branch.adb \
  tests/verification_symbolic_prepost.adb \
  tests/verification_loop_vc_relational.adb \
  tests/verification_array_index_clean.adb \
  tests/verification_many_variables.adb || status=$?
if [ "$status" -gt 1 ]; then
   echo "AdaLang Analyzer differential run failed with status $status" >&2
   exit "$status"
fi

grep -F '"status": "proved-safe"' "$results" >/dev/null
if grep -F '"status": "definite-error"' "$results" >/dev/null ||
  grep -F '"status": "unsupported"' "$results" >/dev/null; then
   echo "AdaLang contradicted the clean GNATprove corpus" >&2
   exit 1
fi

if ! "$gnatprove" -P tests/verification_differential.gpr \
  --mode=prove --level=0 >"$gnatprove_log" 2>&1; then
   cat "$gnatprove_log"
   exit 1
fi
cat "$gnatprove_log"
grep -F 'Success: all checks proved' "$gnatprove_log" >/dev/null

summary=obj/verification_differential/gnatprove/gnatprove.out
grep -F 'Analyzed 11 units' "$summary" >/dev/null
if grep -F ' skipped;' "$summary" >/dev/null; then
   echo "GNATprove skipped part of the differential corpus" >&2
   exit 1
fi

# The corpus above only shows agreement when both tools see safe code. The
# opposite failure mode -- AdaLang claiming Proved_Safe on code GNATprove
# rejects -- is just as important, so a second corpus of deliberately broken
# fixtures checks that GNATprove also fails to prove each one, and that the
# internal test suite (run_verification.sh) never lets AdaLang mark the
# broken obligation itself Proved_Safe.
status=0
"$analyzer" --verify -q --format=json --output="$broken_results" \
  tests/verification_vc_error.adb \
  tests/verification_loop_vc_broken.adb \
  tests/verification_initialization_error.adb \
  tests/verification_symbolic_call.adb \
  tests/verification_symbolic_join.adb || status=$?
if [ "$status" -gt 1 ]; then
   echo "AdaLang Analyzer broken-corpus run failed with status $status" >&2
   exit "$status"
fi

"$gnatprove" -P tests/verification_differential_broken.gpr \
  --mode=prove --level=0 >"$broken_gnatprove_log" 2>&1 || true
cat "$broken_gnatprove_log"
if grep -F 'Success: all checks proved' "$broken_gnatprove_log" >/dev/null; then
   echo "GNATprove unexpectedly proved the broken differential corpus;" \
     "a fixture no longer contains a genuine defect" >&2
   exit 1
fi

broken_summary=obj/verification_differential_broken/gnatprove/gnatprove.out
for unit in verification_vc_error verification_loop_vc_broken \
  verification_initialization_error verification_symbolic_call \
  verification_symbolic_join; do
   if ! grep -F "in unit $unit," "$broken_summary" >/dev/null; then
      echo "GNATprove did not analyze $unit in the broken corpus" >&2
      exit 1
   fi
done
if ! grep -F 'not proved' "$broken_summary" >/dev/null; then
   echo "GNATprove reported no failures in the broken differential corpus" >&2
   exit 1
fi

echo "GNATprove differential tests passed"
