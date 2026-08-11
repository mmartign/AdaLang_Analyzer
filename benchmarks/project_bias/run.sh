#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
project_bias_root=${PROJECT_BIAS_ROOT:?set PROJECT_BIAS_ROOT to the pinned EliAvila10/project_bias checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/project_bias}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}

if [ "${ALIRE:-}" != "True" ]; then
   exec alr exec -- "$0" "$@"
fi

expected_revision=$(sed -n '1p' "$benchmark_dir/PROJECT_BIAS_REVISION")
actual_revision=$(git -C "$project_bias_root" rev-parse HEAD)

if [ "$actual_revision" != "$expected_revision" ]; then
   echo "project_bias revision mismatch: expected $expected_revision, found $actual_revision" >&2
   exit 1
fi

project=$project_bias_root/project_bias.gpr
comparison_script=$repository_root/benchmarks/sparknacl/compare.awk
mkdir -p "$results_dir"

run_adalang () {
   lane=$1
   preset=$2
   status=0

   /usr/bin/time -p -o "$results_dir/adalang-$lane.time" \
     "$analyzer" "-P$project" "$preset" -q \
     --no-config --format=json \
     --output="$results_dir/adalang-$lane.json" \
     2>"$results_dir/adalang-$lane.stderr" || status=$?

   # Status 1 means findings or obligations were emitted. Higher statuses
   # are invocation or analysis failures and invalidate the lane.
   if [ "$status" -gt 1 ]; then
      echo "AdaLang $lane lane failed with status $status" >&2
      exit "$status"
   fi

   if command -v jq >/dev/null 2>&1; then
      jq '{
        analyzedFiles: (.analysisConfiguration.analyzedFiles | length),
        findings: (.findings | length),
        findingsByRule: (.findings
          | group_by(.ruleId)
          | map({key: .[0].ruleId, value: length})
          | from_entries),
        proofSummary: .proofSummary,
        proofObligations: (.proofObligations | length)
      }' "$results_dir/adalang-$lane.json" \
        >"$results_dir/adalang-$lane-summary.json"
   fi
}

run_adalang recommended --recommended
run_adalang spark --spark
run_adalang verify --verify

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

# The project declares no Prove package. Keep the proof budget explicit and
# stable: the three-prover set matches the other comparison benchmarks, while
# the step and timeout limits reproduce this corpus's first recorded run.
status=0
/usr/bin/time -p -o "$results_dir/gnatprove-prove.time" \
  "$gnatprove" "-P$project" --mode=prove -f -q --output=oneline \
  --prover=z3,cvc5,altergo --steps=16000 --timeout=10 \
  --report=statistics \
  >"$results_dir/gnatprove-prove.oneline" 2>&1 || status=$?
printf '%s\n' "$status" >"$results_dir/gnatprove-prove.status"

gnatprove_summary=$(find "$project_bias_root/obj" \
  -path '*/gnatprove/gnatprove.out' -print -quit 2>/dev/null || true)
if [ -n "$gnatprove_summary" ] && [ -f "$gnatprove_summary" ]; then
   cp "$gnatprove_summary" "$results_dir/gnatprove.out"
fi

awk -v corpus_label=project_bias -f "$comparison_script" \
  "$results_dir/adalang-verify.json" \
  "$results_dir/gnatprove-prove.oneline" \
  >"$results_dir/comparison.txt"

cat "$results_dir/comparison.txt"
echo "project_bias benchmark results written to $results_dir"
