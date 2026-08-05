#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
adl_root=${ADL_ROOT:?set ADL_ROOT to the pinned AdaCore/Ada_Drivers_Library checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/ada_drivers_library}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}
corpus_dir=$adl_root/arch/ARM/STM32/drivers

#  A GNAT toolchain (specifically gnatls) must be resolvable on PATH: without
#  it, Libadalang's own project/runtime source-path lookup for with'd units
#  like Interfaces fails, which degrades some checks (FP-029) -- same
#  rationale as benchmarks/aws/run.sh and benchmarks/sparknacl/run.sh. Re-exec
#  under this repository's own Alire environment supplies it. Note this
#  benchmark never needs an ARM cross toolchain: AdaLang parses and checks
#  the sources directly (no -P, no board scenario variables, no build), so a
#  native host GNAT is all that is required.
if [ "${ALIRE:-}" != "True" ]; then
   exec alr exec -- "$0" "$@"
fi

expected_adl=$(sed -n '1p' "$benchmark_dir/ADL_REVISION")
actual_adl=$(git -C "$adl_root" rev-parse HEAD)

if [ "$actual_adl" != "$expected_adl" ]; then
   echo "Ada_Drivers_Library revision mismatch: expected $expected_adl, found $actual_adl" >&2
   exit 1
fi

if [ ! -d "$corpus_dir" ]; then
   echo "corpus directory not found: $corpus_dir" >&2
   exit 1
fi

mkdir -p "$results_dir"

file_list=$results_dir/files.txt
find "$corpus_dir" -name '*.ads' -o -name '*.adb' | sort >"$file_list"

#  Build the positional-argument file list POSIX-sh style (no bash arrays):
#  every file under corpus_dir is passed directly, with no -P project. There
#  is no board-specific project file that covers just this driver subset
#  without also pulling in board/MCU scenario variables and an ARM cross
#  toolchain this benchmark does not need -- AdaLang only has to parse and
#  check the sources, not build them, and (unlike benchmarks/aws/,
#  benchmarks/sparknacl/, etc.) there is no GNATprove lane here to require a
#  buildable project either. Libadalang's file-list unit provider resolves
#  the with-graph among the files actually passed, the same mechanism
#  run_circular_dependencies.sh relies on for its own whole-program check.
set --
while IFS= read -r source_file; do
   set -- "$@" "$source_file"
done <"$file_list"

run_adalang () {
   lane=$1
   preset=$2
   shift 2
   status=0

   /usr/bin/time -p -o "$results_dir/adalang-$lane.time" \
     "$analyzer" "$preset" -q \
     --no-config --format=json \
     --output="$results_dir/adalang-$lane.json" \
     "$@" \
     2>"$results_dir/adalang-$lane.stderr" || status=$?

   #  Status 1 means findings were emitted. Higher statuses are invocation or
   #  analysis failures and invalidate the lane.
   if [ "$status" -gt 1 ]; then
      echo "AdaLang $lane lane failed with status $status" >&2
      exit "$status"
   fi
}

run_adalang recommended --recommended "$@"
run_adalang spark --spark "$@"
run_adalang automotive --automotive "$@"

if command -v jq >/dev/null 2>&1; then
   for lane in recommended spark automotive; do
      jq '{
        analyzedFiles: .filesScanned,
        findings: (.findings | length),
        byRule: (.findings | group_by(.ruleId) | map({(.[0].ruleId): length}) | add)
      }' "$results_dir/adalang-$lane.json" \
        >"$results_dir/adalang-$lane-summary.json"
   done
fi

echo "Ada_Drivers_Library benchmark results written to $results_dir"
