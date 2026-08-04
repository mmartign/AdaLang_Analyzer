#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
sparknacl_root=${SPARKNACL_ROOT:?set SPARKNACL_ROOT to the pinned rod-chapman/SPARKnaCl checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/sparknacl}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}

#  A GNAT toolchain (specifically gnatls) must be resolvable on PATH: without
#  it, Libadalang's own project/runtime source-path lookup for with'd units
#  like Interfaces fails, which triggers FP-029 (a Property_Error dereferencing
#  a null access) on every SPARKNaCl file that subtypes an Interfaces scalar
#  type -- nearly all of them -- and silently drops most proof obligations.
#  Re-exec under this repository's own Alire environment supplies it, the
#  same way benchmarks/aws/run.sh does.
if [ "${ALIRE:-}" != "True" ]; then
   exec alr exec -- "$0" "$@"
fi

expected_sparknacl=$(sed -n '1p' "$benchmark_dir/SPARKNACL_REVISION")
actual_sparknacl=$(git -C "$sparknacl_root" rev-parse HEAD)

if [ "$actual_sparknacl" != "$expected_sparknacl" ]; then
   echo "SPARKNaCl revision mismatch: expected $expected_sparknacl, found $actual_sparknacl" >&2
   exit 1
fi

mkdir -p "$results_dir"

project=$sparknacl_root/sparknacl.gpr

status=0
/usr/bin/time -p -o "$results_dir/adalang-verify.time" \
  "$analyzer" "-P$project" --verify -q \
  --no-config --format=json \
  --output="$results_dir/adalang-verify.json" \
  2>"$results_dir/adalang-verify.stderr" || status=$?

#  Status 1 means findings/obligations were emitted. Higher statuses are
#  invocation or analysis failures and invalidate the run.
if [ "$status" -gt 1 ]; then
   echo "AdaLang verify lane failed with status $status" >&2
   exit "$status"
fi

if command -v jq >/dev/null 2>&1; then
   jq '{
     analyzedFiles: (.analysisConfiguration.analyzedFiles | length),
     proofSummary: .proofSummary,
     proofObligations: (.proofObligations | length)
   }' "$results_dir/adalang-verify.json" \
     >"$results_dir/adalang-verify-summary.json"
fi

gnatprove=${GNATPROVE:-}
if [ -z "$gnatprove" ]; then
   gnatprove=$(command -v gnatprove || true)
fi
if [ -z "$gnatprove" ] && [ -n "${HOME:-}" ] \
  && [ -x "${HOME}/.alire/bin/gnatprove" ]; then
   gnatprove=${HOME}/.alire/bin/gnatprove
fi

if [ -z "$gnatprove" ]; then
   echo "GNATprove lane skipped: executable not found" >&2
   exit 1
fi

#  SPARKNaCl's own sparknacl.gpr already carries a tuned Prove package
#  (level=4, z3/cvc5/altergo, timeout=60, steps=140000) -- that configuration
#  is what backs its "fully proved" claim, so it is used unmodified rather
#  than a weaker ad hoc setting here.
#  GNATprove writes its --output=oneline check messages to stderr, not
#  stdout (confirmed empirically); the two streams are merged here so the
#  comparator sees them regardless of which one a future GNATprove version
#  picks.
status=0
/usr/bin/time -p -o "$results_dir/gnatprove-prove.time" \
  "$gnatprove" "-P$project" --mode=prove -f -q --output=oneline \
  >"$results_dir/gnatprove-prove.oneline" 2>&1 || status=$?
printf '%s\n' "$status" >"$results_dir/gnatprove-prove.status"

gnatprove_summary=$sparknacl_root/obj/gnatprove/gnatprove.out
if [ -f "$gnatprove_summary" ]; then
   cp "$gnatprove_summary" "$results_dir/gnatprove.out"
fi

awk -f "$benchmark_dir/compare.awk" \
  "$results_dir/adalang-verify.json" \
  "$results_dir/gnatprove-prove.oneline" \
  >"$results_dir/comparison.txt"

cat "$results_dir/comparison.txt"
echo "SPARKNaCl benchmark results written to $results_dir"
