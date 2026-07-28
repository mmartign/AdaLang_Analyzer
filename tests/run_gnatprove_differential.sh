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
trap 'rm -f "$results" "$gnatprove_log"' EXIT HUP INT TERM

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
  tests/verification_loop_vc_relational.adb || status=$?
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
grep -F 'Analyzed 9 units' "$summary" >/dev/null
if grep -F ' skipped;' "$summary" >/dev/null; then
   echo "GNATprove skipped part of the differential corpus" >&2
   exit 1
fi

echo "GNATprove differential tests passed"
