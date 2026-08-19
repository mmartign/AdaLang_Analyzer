#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
adl_root=${ADL_ROOT:?set ADL_ROOT to the pinned AdaCore/Ada_Drivers_Library checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/ada_drivers_library}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}
rule_map=$repository_root/benchmarks/gnatcheck_rule_map.tsv
corpus_dir=$adl_root/arch/ARM/STM32/drivers

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

#  Build the positional-argument file list POSIX-sh style (no bash arrays),
#  same as run.sh: every file under corpus_dir is passed directly, with no
#  -P project (this driver subset has no project file of its own -- see
#  benchmarks/ada_drivers_library/README.md).
set --
while IFS= read -r source_file; do
   set -- "$@" "$source_file"
done <"$file_list"

adalang_checks=$(awk -F'\t' 'NR>1 && $1!="No_Recursion"{print $1}' "$rule_map" | sort -u | tr '\n' ',' | sed 's/,$//')
gc_rule_args=$(awk -F'\t' 'NR>1 && $2!="recursive_subprograms"{print $2}' "$rule_map" | sort -u | awk '{printf "-r %s ", $0}')

#  Run the AdaLang lane FIRST, under this repository's own alr-exec
#  environment only (see benchmarks/aws/run_gnatcheck.sh's comment for why
#  GNATCHECK_ENV must not be sourced before this point: it carries its own
#  trimmed, runtime-only GPR_PROJECT_PATH that can shadow real project
#  dependencies). This benchmark has no -P project and no external
#  dependencies at all, so the ordering risk is smaller here than for AWS
#  or gnatcoll-core, but the same discipline is followed for consistency.
status=0
"$analyzer" "-checks=$adalang_checks" --format=json -q \
  --output="$results_dir/adalang-gnatcheck-compare.json" \
  "$@" \
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

#  Unlike AdaLang (which parses the flat 90-file list directly via
#  Libadalang's file-list unit provider -- see README.md), GNATcheck needs
#  a GPR project, and a single project covering all of
#  arch/ARM/STM32/drivers/ is impossible: the tree deliberately holds
#  mutually-exclusive board-variant subdirectories that redeclare the same
#  package under the same basename (e.g. crc_stm32f4/stm32-crc.ads and
#  crc_stm32f7/stm32-crc.ads both provide Stm32.Crc) -- a real GNAT project
#  cannot have two source files with the same basename in one closure ("The
#  source with basename ... appears multiple times"). There are six such
#  variant pairs (crc_stm32f4/f7, devid_stm32f4/f7, dma vs.
#  dma_stm32f769, i2c_stm32f4/f7, power_control_stm32f4/f7, sd/sdio vs.
#  sd/sdmmc). The 90 files were partitioned by hand into two
#  non-conflicting, non-overlapping GPR projects -- set A takes one member
#  of each pair (plus every unpaired directory and the top-level files),
#  set B takes the other -- verified (via `diff` against a flat `find`
#  listing) to reconstruct the exact same 90 files with no gaps or overlap.
#  GNATcheck is run once per project and the two `gnatcheck.txt` outputs are
#  concatenated, so every file gets exactly one GNATcheck pass, the same as
#  AdaLang's single combined run.
set_a_dirs="crc_stm32f4 devid_stm32f4 dma_stm32f769 i2c_stm32f4 power_control_stm32f4 sd/sdio sd dma2d dma_interrupts dsi fmc fsmc ltdc sai uart_stm32f4 ."
set_b_dirs="crc_stm32f7 devid_stm32f7 dma i2c_stm32f7 power_control_stm32f7 sd/sdmmc"

write_variant_project () {
   #  $1 = project file path, $2 = object dir, $3 = space-separated dir list
   gpr_path=$1
   obj_dir=$2
   dirs=$3
   mkdir -p "$obj_dir"
   {
      echo "project Adl_Gnatcheck_Variant is"
      printf '   for Source_Dirs use ('
      first=true
      for d in $dirs; do
         if [ "$first" = true ]; then first=false; else printf ', '; fi
         printf '"%s"' "$corpus_dir/$d"
      done
      printf ');\n'
      echo "   for Object_Dir use \"$obj_dir\";"
      echo "end Adl_Gnatcheck_Variant;"
   } >"$gpr_path"
}

write_variant_project "$results_dir/adl_gnatcheck_variant_a.gpr" \
  "$results_dir/gnatcheck-obj-a" "$set_a_dirs"
write_variant_project "$results_dir/adl_gnatcheck_variant_b.gpr" \
  "$results_dir/gnatcheck-obj-b" "$set_b_dirs"

: >"$results_dir/gnatcheck.txt"
final_status=0
for variant in a b; do
   status=0
   # shellcheck disable=SC2086
   eval "\"\$gnatcheck\" -P\"\$results_dir/adl_gnatcheck_variant_$variant.gpr\" -U --show-rule $gc_rule_args" \
     >>"$results_dir/gnatcheck.txt" 2>&1 || status=$?
   if [ "$status" -gt "$final_status" ]; then
      final_status=$status
   fi
done
printf '%s\n' "$final_status" >"$results_dir/gnatcheck.status"
if [ "$final_status" -gt 1 ]; then
   echo "GNATcheck lane exited $final_status -- check $results_dir/gnatcheck.txt before trusting the comparison" >&2
fi

awk -f "$repository_root/benchmarks/gnatcheck_compare.awk" \
  "$results_dir/adalang-gnatcheck-compare.json" \
  "$results_dir/gnatcheck.txt" \
  "$rule_map" \
  >"$results_dir/gnatcheck-comparison.txt"

cat "$results_dir/gnatcheck-comparison.txt"
echo "Ada_Drivers_Library GNATcheck-oracle results written to $results_dir"
