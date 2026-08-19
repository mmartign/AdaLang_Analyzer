#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
saatana_root=${SAATANA_ROOT:?set SAATANA_ROOT to the pinned HeisenbugLtd/Saatana checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/saatana}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}
rule_map=$repository_root/benchmarks/gnatcheck_rule_map.tsv

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

adalang_checks=$(awk -F'\t' 'NR>1 && $1!="No_Recursion"{print $1}' "$rule_map" | sort -u | tr '\n' ',' | sed 's/,$//')
gc_rule_args=$(awk -F'\t' 'NR>1 && $2!="recursive_subprograms"{print $2}' "$rule_map" | sort -u | awk '{printf "-r %s ", $0}')

#  Run the AdaLang lane FIRST, before GNATCHECK_ENV is sourced below -- see
#  benchmarks/aws/run_gnatcheck.sh's comment for the failure mode this
#  ordering avoids (GNATCHECK_ENV's own trimmed, runtime-only
#  GPR_PROJECT_PATH shadowing a real project's own dependencies). Saatana
#  has no external project dependencies beyond `gnat` itself, so this run
#  is not expected to hit that specific failure mode, but the ordering is
#  kept for consistency with every other corpus's script.
status=0
"$analyzer" "-P$project" "-checks=$adalang_checks" --format=json -q \
  --output="$results_dir/adalang-gnatcheck-compare.json" \
  2>"$results_dir/adalang-gnatcheck-compare.stderr" || status=$?
if [ "$status" -gt 1 ]; then
   echo "AdaLang gnatcheck-compare lane failed with status $status" >&2
   exit "$status"
fi

#  Only now bring in GNATcheck's own runtime environment (see
#  benchmarks/sparknacl/run_gnatcheck.sh for the availability and
#  rule-exclusion notes: recursive_subprograms crashes this from-source
#  build's global call-graph analysis).
if [ -n "${GNATCHECK_ENV:-}" ]; then
   # shellcheck disable=SC1090
   . "$GNATCHECK_ENV"
fi

gnatcheck=${GNATCHECK:-}
if [ -z "$gnatcheck" ]; then
   gnatcheck=$(command -v gnatcheck || true)
fi
if [ -z "$gnatcheck" ]; then
   echo "GNATcheck lane skipped: executable not found (set GNATCHECK or GNATCHECK_ENV)" >&2
   exit 1
fi

status=0
# shellcheck disable=SC2086
eval "\"\$gnatcheck\" -P\"\$project\" --ignore-project-switches --show-rule $gc_rule_args" \
  >"$results_dir/gnatcheck.txt" 2>&1 || status=$?
printf '%s\n' "$status" >"$results_dir/gnatcheck.status"
if [ "$status" -gt 1 ]; then
   echo "GNATcheck lane exited $status -- check $results_dir/gnatcheck.txt before trusting the comparison" >&2
fi

awk -f "$repository_root/benchmarks/gnatcheck_compare.awk" \
  "$results_dir/adalang-gnatcheck-compare.json" \
  "$results_dir/gnatcheck.txt" \
  "$rule_map" \
  >"$results_dir/gnatcheck-comparison.txt"

cat "$results_dir/gnatcheck-comparison.txt"
echo "Saatana GNATcheck-oracle results written to $results_dir"
