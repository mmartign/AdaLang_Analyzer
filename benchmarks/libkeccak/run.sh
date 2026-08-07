#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
libkeccak_root=${LIBKECCAK_ROOT:?set LIBKECCAK_ROOT to the pinned damaki/libkeccak checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/libkeccak}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}

#  A GNAT toolchain (specifically gnatls) must be resolvable on PATH: without
#  it, Libadalang's own project/runtime source-path lookup for with'd units
#  fails, which triggers FP-029 -- same rationale as benchmarks/sparknacl/run.sh,
#  benchmarks/saatana/run.sh, and benchmarks/aws/run.sh. Re-exec under this
#  repository's own Alire environment supplies it.
if [ "${ALIRE:-}" != "True" ]; then
   exec alr exec -- "$0" "$@"
fi

expected_libkeccak=$(sed -n '1p' "$benchmark_dir/LIBKECCAK_REVISION")
actual_libkeccak=$(git -C "$libkeccak_root" rev-parse HEAD)

if [ "$actual_libkeccak" != "$expected_libkeccak" ]; then
   echo "Libkeccak revision mismatch: expected $expected_libkeccak, found $actual_libkeccak" >&2
   exit 1
fi

project=$libkeccak_root/libkeccak.gpr
scenario_args="-XLIBKECCAK_ARCH=generic -XLIBKECCAK_SIMD=none"

#  libkeccak.gpr with's config/libkeccak_config.gpr, which Alire generates
#  (it is not checked into the repository). Run `alr build` once in
#  $LIBKECCAK_ROOT before this script, as documented in
#  benchmarks/libkeccak/README.md.
if [ ! -f "$libkeccak_root/config/libkeccak_config.gpr" ]; then
   echo "libkeccak is not configured: run 'alr build' in $libkeccak_root first" >&2
   echo "see benchmarks/libkeccak/README.md" >&2
   exit 1
fi

mkdir -p "$results_dir"

status=0
/usr/bin/time -p -o "$results_dir/adalang-verify.time" \
  "$analyzer" "-P$project" $scenario_args --verify -q \
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

#  libkeccak.gpr's own package Prove names "--prover=cvc4,z3,altergo". This
#  benchmark's GNATprove (the same FSF 16.1.0 / Why3 1.8.2+git / CVC5 1.3.2
#  pin the other benchmarks in this directory document) does not ship CVC4 --
#  the modern SPARK Community/FSF toolchain bundles CVC5 instead. Run
#  unmodified, GNATprove aborts outright ("Selected prover not installed or
#  not configured") on every check, the same category of environment gap as
#  FP-029 and benchmarks/saatana/'s own CVC4 override, not an AdaLang defect.
#  --prover=z3,cvc5,altergo on the command line substitutes CVC5 for CVC4;
#  the project's own --steps=16000 and --timeout=60 are otherwise left
#  unmodified, since (unlike Saatana's per-file switches) libkeccak's Prove
#  package switches were not tuned for CVC4 specifically and this benchmark
#  did not observe step/timeout-limited residuals from the substitution
#  alone.
status=0
/usr/bin/time -p -o "$results_dir/gnatprove-prove.time" \
  "$gnatprove" "-P$project" $scenario_args --mode=prove -f -q --output=oneline \
  --prover=z3,cvc5,altergo \
  >"$results_dir/gnatprove-prove.oneline" 2>&1 || status=$?
printf '%s\n' "$status" >"$results_dir/gnatprove-prove.status"

gnatprove_summary=$libkeccak_root/obj/generic_none/gnatprove/gnatprove.out
if [ -f "$gnatprove_summary" ]; then
   cp "$gnatprove_summary" "$results_dir/gnatprove.out"
fi

awk -f "$benchmark_dir/compare.awk" \
  "$results_dir/adalang-verify.json" \
  "$results_dir/gnatprove-prove.oneline" \
  >"$results_dir/comparison.txt"

cat "$results_dir/comparison.txt"
echo "Libkeccak benchmark results written to $results_dir"
