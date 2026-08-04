#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
cubedos_root=${CUBEDOS_ROOT:?set CUBEDOS_ROOT to the pinned cubesatlab/cubedos checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/cubedos}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}

expected_cubedos=$(sed -n '1p' "$benchmark_dir/CUBEDOS_REVISION")
actual_cubedos=$(git -C "$cubedos_root" rev-parse HEAD)

if [ "$actual_cubedos" != "$expected_cubedos" ]; then
   echo "CubedOS revision mismatch: expected $expected_cubedos, found $actual_cubedos" >&2
   exit 1
fi

mkdir -p "$results_dir"

#  Unlike SPARKNaCl, CubedOS's own src/cubedos.gpr withs "aunit.gpr" (its
#  check/ subtree is an AUnit test suite). Rather than modify the pinned
#  corpus or this repository's own alire.toml, resolve AUnit through a
#  throwaway local Alire crate cached under this benchmark's results
#  directory, and add its GPR_PROJECT_PATH entry to the environment. This
#  crate has no source of its own beyond a trivial placeholder body; it
#  exists only to make `alr` fetch and build aunit=26.0.0 and report where.
#  This whole block, and the re-exec below, are gated on the same "not yet
#  ALIRE" condition and run exactly once: alr refuses to nest two different
#  toolchain pins in one process (this repository's gnat_native pin vs.
#  whatever aunit's own crate resolves to), so the throwaway crate must be
#  built in a plain, not-yet-ALIRE shell, and never repeated after the
#  exec re-enters this script with ALIRE=True.
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

   #  Same rationale as benchmarks/sparknacl/run.sh: re-exec under this
   #  repository's own Alire environment so gnatls is resolvable (FP-029)
   #  and the pinned Libadalang/GNAT toolchain is on PATH.
   #  GPR_PROJECT_PATH, exported above, survives the exec.
   exec alr exec -- "$0" "$@"
fi

project=$cubedos_root/src/cubedos.gpr

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

#  CubedOS's own cubedos.gpr declares an empty "package Prove" (no pinned
#  level/prover/timeout), unlike SPARKNaCl's tuned Prove package. This
#  benchmark picks level=4 with the same three-prover, 60s-timeout
#  configuration SPARKNaCl's own project uses, for methodological
#  consistency across both corpora rather than reusing an unset default.
status=0
/usr/bin/time -p -o "$results_dir/gnatprove-prove.time" \
  "$gnatprove" "-P$project" --mode=prove --level=4 \
  --prover=z3,cvc5,altergo --timeout=60 -j0 -f -q --output=oneline \
  >"$results_dir/gnatprove-prove.oneline" 2>&1 || status=$?
printf '%s\n' "$status" >"$results_dir/gnatprove-prove.status"

gnatprove_summary=$cubedos_root/obj/gnatprove/gnatprove.out
if [ -f "$gnatprove_summary" ]; then
   cp "$gnatprove_summary" "$results_dir/gnatprove.out"
fi

awk -f "$benchmark_dir/compare.awk" \
  "$results_dir/adalang-verify.json" \
  "$results_dir/gnatprove-prove.oneline" \
  >"$results_dir/comparison.txt"

cat "$results_dir/comparison.txt"
echo "CubedOS benchmark results written to $results_dir"
