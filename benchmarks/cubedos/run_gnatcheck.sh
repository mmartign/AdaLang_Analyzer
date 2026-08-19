#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
cubedos_root=${CUBEDOS_ROOT:?set CUBEDOS_ROOT to the pinned cubesatlab/cubedos checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/cubedos}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}
rule_map=$repository_root/benchmarks/gnatcheck_rule_map.tsv

mkdir -p "$results_dir"

#  Unlike SPARKNaCl, CubedOS's own src/cubedos.gpr withs "aunit.gpr" (its
#  check/ subtree is an AUnit test suite). Resolve AUnit through the same
#  throwaway local Alire crate benchmarks/cubedos/run.sh uses (reused here
#  verbatim, cached under this benchmark's results directory) and add its
#  GPR_PROJECT_PATH entry to the environment, in a plain, not-yet-ALIRE
#  shell: alr refuses to nest two different toolchain pins in one process,
#  so this step and the re-exec below cannot be combined, and must run
#  exactly once, before ALIRE=True.
if [ "${ALIRE:-}" != "True" ]; then
   aunit_crate_dir=$results_dir/aunit_provider
   if [ ! -f "$aunit_crate_dir/alire.toml" ]; then
      mkdir -p "$aunit_crate_dir/src"
      cat >"$aunit_crate_dir/alire.toml" <<'EOF'
name = "aunit_provider"
description = "Throwaway crate resolving aunit for the CubedOS benchmark"
version = "0.1.0"
authors = ["adalang_analyzer benchmark"]
maintainers = ["adalang_analyzer benchmark <noreply@example.com>"]
licenses = "GPL-3.0-or-later"

project-files = ["aunit_provider.gpr"]

[[depends-on]]
aunit = "*"
EOF
      cat >"$aunit_crate_dir/aunit_provider.gpr" <<'EOF'
project Aunit_Provider is
   for Source_Dirs use ("src");
   for Object_Dir use "obj";
   for Main use ("main.adb");
end Aunit_Provider;
EOF
      cat >"$aunit_crate_dir/src/main.adb" <<'EOF'
procedure Main is
begin
   null;
end Main;
EOF
   fi

   (cd "$aunit_crate_dir" && alr -q build)
   aunit_gpr_path=$(cd "$aunit_crate_dir" && alr printenv \
     | sed -n 's/^export GPR_PROJECT_PATH="\([^:]*\).*/\1/p')
   if [ -z "$aunit_gpr_path" ]; then
      echo "Could not resolve aunit's GPR_PROJECT_PATH from $aunit_crate_dir" >&2
      exit 1
   fi
   GPR_PROJECT_PATH=$aunit_gpr_path${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}
   export GPR_PROJECT_PATH

   #  Same rationale as benchmarks/sparknacl/run_gnatcheck.sh: re-exec under
   #  this repository's own Alire environment so gnatls is resolvable and
   #  the pinned Libadalang/GNAT toolchain is on PATH, BEFORE GNATCHECK_ENV
   #  (sourced further below, only for the GNATcheck lane) is ever brought
   #  in -- see benchmarks/aws/run_gnatcheck.sh's comment for the failure
   #  mode that ordering avoids. GPR_PROJECT_PATH, exported above, survives
   #  the exec.
   exec alr exec -- "$0" "$@"
fi

expected_cubedos=$(sed -n '1p' "$benchmark_dir/CUBEDOS_REVISION")
actual_cubedos=$(git -C "$cubedos_root" rev-parse HEAD)
if [ "$actual_cubedos" != "$expected_cubedos" ]; then
   echo "CubedOS revision mismatch: expected $expected_cubedos, found $actual_cubedos" >&2
   exit 1
fi

project=$cubedos_root/src/cubedos.gpr

adalang_checks=$(awk -F'\t' 'NR>1 && $1!="No_Recursion"{print $1}' "$rule_map" | sort -u | tr '\n' ',' | sed 's/,$//')
gc_rule_args=$(awk -F'\t' 'NR>1 && $2!="recursive_subprograms"{print $2}' "$rule_map" | sort -u | awk '{printf "-r %s ", $0}')

#  Run the AdaLang lane FIRST, under the aunit-resolved alr-exec environment
#  set up above and nothing else -- sourcing GNATCHECK_ENV before this point
#  would leak the from-source GNATcheck build's own trimmed, runtime-only
#  GPR_PROJECT_PATH in ahead of the aunit crate's, the same failure mode
#  documented in benchmarks/aws/run_gnatcheck.sh.
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
#  build's global call-graph analysis). Its own GPR_PROJECT_PATH is
#  appended (lower priority), since sourcing GNATCHECK_ENV overwrites the
#  variable rather than extending it, and the aunit crate's own resolution
#  (captured here before the source, since re-exec above only preserves the
#  exported GPR_PROJECT_PATH itself, not the aunit_gpr_path shell variable
#  that built it) must keep winning.
pre_gnatcheck_gpr_project_path=$GPR_PROJECT_PATH
if [ -n "${GNATCHECK_ENV:-}" ]; then
   # shellcheck disable=SC1090
   . "$GNATCHECK_ENV"
fi
GPR_PROJECT_PATH="$pre_gnatcheck_gpr_project_path${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
export GPR_PROJECT_PATH

gnatcheck=${GNATCHECK:-}
if [ -z "$gnatcheck" ]; then
   gnatcheck=$(command -v gnatcheck || true)
fi
if [ -z "$gnatcheck" ]; then
   echo "GNATcheck lane skipped: executable not found (set GNATCHECK or GNATCHECK_ENV)" >&2
   exit 1
fi

#  cubedos.gpr declares its own "package Check" with
#  "-rules -from=cubedos-rules.txt" in Default_Switches, which GNATcheck
#  auto-loads from the project by default -- several of its rule names
#  collide with this benchmark's own command-line -r flags ("cannot add
#  rule instance ... already instantiated"), which does not break the run
#  (the command-line instantiation wins) but pollutes gnatcheck.txt with
#  spurious errors and a nonzero exit status. --ignore-project-switches
#  keeps this run's rule set exactly the shared map's, with no CubedOS-
#  specific rule configuration silently mixed in, for the same
#  cross-corpus methodological consistency benchmarks/cubedos/run.sh's own
#  GNATprove lane already applies (explicit --level=4 rather than
#  cubedos.gpr's unset default Prove package).
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
echo "CubedOS GNATcheck-oracle results written to $results_dir"
