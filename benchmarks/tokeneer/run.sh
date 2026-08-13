#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
tokeneer_root=${TOKENEER_ROOT:?set TOKENEER_ROOT to the pinned AdaCore/spark2014 checkout (sparse on testsuite/gnatprove/tests/tokeneer is enough)}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/tokeneer}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}

#  A GNAT toolchain (specifically gnatls) must be resolvable on PATH: without
#  it, Libadalang's own project/runtime source-path lookup for with'd units
#  fails, which triggers FP-029 -- same rationale as benchmarks/sparknacl/,
#  benchmarks/saatana/, benchmarks/aws/, benchmarks/libkeccak/, and
#  benchmarks/coap_spark/'s run.sh.
if [ "${ALIRE:-}" != "True" ]; then
   exec alr exec -- "$0" "$@"
fi

tokeneer_dir=$tokeneer_root/testsuite/gnatprove/tests/tokeneer
expected_revision=$(sed -n '1p' "$benchmark_dir/TOKENEER_REVISION")
actual_revision=$(git -C "$tokeneer_root" rev-parse HEAD)

if [ "$actual_revision" != "$expected_revision" ]; then
   echo "spark2014 revision mismatch: expected $expected_revision, found $actual_revision" >&2
   exit 1
fi
if [ ! -f "$tokeneer_dir/test.gpr" ]; then
   echo "TOKENEER_ROOT ($tokeneer_root) has no testsuite/gnatprove/tests/tokeneer/test.gpr" >&2
   echo "a sparse checkout of that one subdirectory from AdaCore/spark2014 is enough -- see README.md" >&2
   exit 1
fi

mkdir -p "$results_dir"

project=$tokeneer_dir/test.gpr

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

#  test.gpr's own Prove package (--function-sandboxing=off,
#  --proof-warnings=on, --level=2) sets no --report switch, which leaves
#  GNATprove's default of reporting only failed checks in --output=oneline
#  mode -- almost nothing for compare.awk to match against AdaLang's
#  obligations, the same gap benchmarks/saatana/ and benchmarks/coap_spark/
#  hit and fixed the same way. --report=statistics adds an "info: ...
#  proved" line per successfully discharged check.
status=0
/usr/bin/time -p -o "$results_dir/gnatprove-prove.time" \
  "$gnatprove" "-P$project" --mode=prove -f -q --output=oneline \
  --report=statistics \
  >"$results_dir/gnatprove-prove.oneline" 2>&1 || status=$?
printf '%s\n' "$status" >"$results_dir/gnatprove-prove.status"

gnatprove_summary=$tokeneer_dir/gnatprove/gnatprove.out
if [ -f "$gnatprove_summary" ]; then
   cp "$gnatprove_summary" "$results_dir/gnatprove.out"
fi

awk -f "$benchmark_dir/compare.awk" \
  "$results_dir/adalang-verify.json" \
  "$results_dir/gnatprove-prove.oneline" \
  >"$results_dir/comparison.txt"

cat "$results_dir/comparison.txt"
echo "Tokeneer benchmark results written to $results_dir"
