#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
saatana_root=${SAATANA_ROOT:?set SAATANA_ROOT to the pinned HeisenbugLtd/Saatana checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/saatana}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}

#  A GNAT toolchain (specifically gnatls) must be resolvable on PATH: without
#  it, Libadalang's own project/runtime source-path lookup for with'd units
#  like Interfaces fails, which triggers FP-029 (a Property_Error dereferencing
#  a null access) -- same rationale as benchmarks/sparknacl/run.sh and
#  benchmarks/aws/run.sh. Re-exec under this repository's own Alire
#  environment supplies it.
if [ "${ALIRE:-}" != "True" ]; then
   exec alr exec -- "$0" "$@"
fi

expected_saatana=$(sed -n '1p' "$benchmark_dir/SAATANA_REVISION")
actual_saatana=$(git -C "$saatana_root" rev-parse HEAD)

if [ "$actual_saatana" != "$expected_saatana" ]; then
   echo "Saatana revision mismatch: expected $expected_saatana, found $actual_saatana" >&2
   exit 1
fi

mkdir -p "$results_dir"

project=$saatana_root/saatana.gpr

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

#  Saatana's own saatana.gpr carries a tuned per-file Prove package (see
#  artifacts/gnatprove.out, checked into the corpus itself: 338 checks
#  total, 0 unproved, 0 justified) -- but one entry
#  (saatana-crypto-phelix.adb: "--prover=Z3,CVC4") names a prover this
#  benchmark's GNATprove toolchain does not ship (the same FSF 16.1.0 /
#  Why3 1.8.2+git / CVC5 1.3.2 pin documented in
#  benchmarks/sparknacl/RESULTS_*.md and benchmarks/cubedos/RESULTS_*.md
#  bundles CVC5, not the older CVC4). Run unmodified, GNATprove aborts
#  outright ("Selected prover not installed or not configured") partway
#  through, the same category of environment gap as FP-029, not an
#  AdaLang defect. --prover=z3,cvc5 on the command line substitutes CVC5
#  for CVC4 project-wide; that alone still leaves 3 medium ("step limit
#  reached") findings on the tight per-file step budgets Saatana tuned
#  for CVC4 specifically. --timeout=60 --steps=0, matching SPARKNaCl's own
#  generous budget, resolves all three back to fully proved (confirmed
#  interactively before wiring this script) -- CVC5 needs a larger budget
#  than CVC4 needed to close the same obligations, not a different result.
#  -U matches Saatana's own CI invocation (.github/scripts/ci-proof.sh),
#  analyzing every unit reachable from either Main, not just the library
#  sources. --report=statistics matches SPARKNaCl's own sparknacl.gpr
#  Prove package (its "--report=statistics" switch): Saatana's own Prove
#  package has no --report switch at all, which leaves GNATprove's default
#  of reporting only failed checks -- fine for Saatana's own CI (which just
#  wants a pass/fail gate) but useless for this benchmark's per-obligation
#  comparison, which needs an "info: <kind> proved" line for every
#  successfully discharged check, not just the residual failures.
status=0
/usr/bin/time -p -o "$results_dir/gnatprove-prove.time" \
  "$gnatprove" "-P$project" --mode=prove -U -f -q --output=oneline \
  --prover=z3,cvc5 --timeout=60 --steps=0 --report=statistics \
  >"$results_dir/gnatprove-prove.oneline" 2>&1 || status=$?
printf '%s\n' "$status" >"$results_dir/gnatprove-prove.status"

gnatprove_summary=$saatana_root/_build/gnatprove/gnatprove.out
if [ -f "$gnatprove_summary" ]; then
   cp "$gnatprove_summary" "$results_dir/gnatprove.out"
fi

awk -f "$benchmark_dir/compare.awk" \
  "$results_dir/adalang-verify.json" \
  "$results_dir/gnatprove-prove.oneline" \
  >"$results_dir/comparison.txt"

cat "$results_dir/comparison.txt"
echo "Saatana benchmark results written to $results_dir"
