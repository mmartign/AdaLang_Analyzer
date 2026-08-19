#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
sparknacl_root=${SPARKNACL_ROOT:?set SPARKNACL_ROOT to the pinned rod-chapman/SPARKnaCl checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/sparknacl}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}
rule_map=$repository_root/benchmarks/gnatcheck_rule_map.tsv

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

#  Build the two rule-argument lists from the shared map. recursive_subprograms
#  is excluded: this locally-built gnatcheck's global call-graph analysis
#  stack-overflows on it even with a raised ulimit (see RESULTS_gnatcheck_*.md).
adalang_checks=$(awk -F'\t' 'NR>1 && $1!="No_Recursion"{print $1}' "$rule_map" | sort -u | tr '\n' ',' | sed 's/,$//')
gc_rule_args=$(awk -F'\t' 'NR>1 && $2!="recursive_subprograms"{print $2}' "$rule_map" | sort -u | awk '{printf "-r %s ", $0}')

#  Run the AdaLang lane FIRST, before GNATCHECK_ENV is sourced below: that
#  env carries its own trimmed, runtime-only GPR_PROJECT_PATH (see
#  project_gnatcheck_acquisition.md) which can silently shadow whatever
#  project-dependency .gpr files AdaLang's own `-P` parsing needs to
#  resolve, on corpora that (unlike this self-contained one) actually have
#  external project dependencies -- see benchmarks/aws/run_gnatcheck.sh's
#  comment for the failure mode this caused there.
status=0
"$analyzer" "-P$project" "-checks=$adalang_checks" --format=json -q \
  --output="$results_dir/adalang-gnatcheck-compare.json" \
  2>"$results_dir/adalang-gnatcheck-compare.stderr" || status=$?
if [ "$status" -gt 1 ]; then
   echo "AdaLang gnatcheck-compare lane failed with status $status" >&2
   exit "$status"
fi

#  gnatcheck has no Alire package and no prebuilt download; it must be built
#  from source (see project_gnatcheck_acquisition.md in this session's
#  memory, or GNATCHECK_RULE_COMPARISON.md's intro, for the full bootstrap).
#  GNATCHECK_ENV, if set, is sourced to bring the built binary's runtime
#  dependencies (PATH, GPR_PROJECT_PATH, JAVA_HOME, a raised `ulimit -s` --
#  the Ada driver stack-overflows on -P project mode without it -- etc.)
#  onto PATH before resolving GNATCHECK itself.
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
eval "\"\$gnatcheck\" -P\"\$project\" --show-rule $gc_rule_args" \
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
echo "SPARKNaCl GNATcheck-oracle results written to $results_dir"
