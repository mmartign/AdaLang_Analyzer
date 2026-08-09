#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
aws_root=${AWS_ROOT:?set AWS_ROOT to the pinned AdaCore/aws checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/aws}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}

if [ "${ALIRE:-}" != "True" ]; then
   exec alr exec -- "$0" "$@"
fi

expected_aws=$(sed -n '1p' "$benchmark_dir/AWS_REVISION")
expected_templates=$(sed -n '1p' "$benchmark_dir/TEMPLATES_PARSER_REVISION")
actual_aws=$(git -C "$aws_root" rev-parse HEAD)
actual_templates=$(git -C "$aws_root/templates_parser" rev-parse HEAD)

if [ "$actual_aws" != "$expected_aws" ]; then
   echo "AWS revision mismatch: expected $expected_aws, found $actual_aws" >&2
   exit 1
fi
if [ "$actual_templates" != "$expected_templates" ]; then
   echo "templates_parser revision mismatch: expected $expected_templates, found $actual_templates" >&2
   exit 1
fi

target=$(gcc -dumpmachine)
target_dir=$aws_root/$target
project_dir=$target_dir/projects
prj_target=${AWS_PRJ_TARGET:-Darwin}

if [ ! -f "$target_dir/makefile.setup" ] || [ ! -d "$project_dir" ]; then
   echo "AWS is not configured for $target" >&2
   echo "run the setup/build command documented in benchmarks/aws/README.md" >&2
   exit 1
fi

mkdir -p "$results_dir"
GPR_PROJECT_PATH="$project_dir${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
export GPR_PROJECT_PATH

project=$aws_root/src/src.gpr
scenario_args="-XTGT_DIR=$target_dir -XPRJ_TARGET=$prj_target -XTARGET=$target"
scenario_args="$scenario_args -XPRJ_BUILD=Debug -XPRJ_XMLADA=Installed"
scenario_args="$scenario_args -XPRJ_LAL=Disabled -XPRJ_LDAP=Disabled"
scenario_args="$scenario_args -XSOCKET=std -XSSL_DYNAMIC=false"
scenario_args="$scenario_args -XLIBRARY_TYPE=static"

run_adalang () {
   lane=$1
   preset=$2
   status=0

   #  Scenario arguments intentionally contain no whitespace, so the split is
   #  stable and keeps this runner POSIX-sh compatible.
   # shellcheck disable=SC2086
   /usr/bin/time -p -o "$results_dir/adalang-$lane.time" \
     "$analyzer" "-P$project" $scenario_args "$preset" -q \
     --no-config --format=json \
     --output="$results_dir/adalang-$lane.json" \
     2>"$results_dir/adalang-$lane.stderr" || status=$?

   #  Status 1 means findings were emitted. Higher statuses are invocation or
   #  analysis failures and invalidate the lane.
   if [ "$status" -gt 1 ]; then
      echo "AdaLang $lane lane failed with status $status" >&2
      exit "$status"
   fi
}

run_adalang recommended --recommended
run_adalang spark --spark
run_adalang verify --verify
run_adalang automotive --automotive

if command -v jq >/dev/null 2>&1; then
   for lane in recommended spark verify automotive; do
      jq '{
        analyzedFiles: (.analysisConfiguration.analyzedFiles | length),
        findings: (.findings | length),
        proofSummary: .proofSummary,
        proofObligations: (.proofObligations | length)
      }' "$results_dir/adalang-$lane.json" \
        >"$results_dir/adalang-$lane-summary.json"
   done
fi

gnatprove=${GNATPROVE:-}
if [ -z "$gnatprove" ]; then
   gnatprove=$(command -v gnatprove || true)
fi
if [ -z "$gnatprove" ] && [ -n "${HOME:-}" ] \
  && [ -x "${HOME}/.alire/bin/gnatprove" ]; then
   gnatprove=${HOME}/.alire/bin/gnatprove
fi

if [ -n "$gnatprove" ]; then
   for mode in flow prove; do
      status=0
      level=
      if [ "$mode" = "prove" ]; then
         level=--level=0
      fi
      # shellcheck disable=SC2086
      /usr/bin/time -p -o "$results_dir/gnatprove-$mode.time" \
        "$gnatprove" "-P$project" $scenario_args --mode="$mode" $level \
        --output=brief --report=all \
        >"$results_dir/gnatprove-$mode.stdout" \
        2>"$results_dir/gnatprove-$mode.stderr" || status=$?
      printf '%s\n' "$status" >"$results_dir/gnatprove-$mode.status"
   done

   if [ "${GNATPROVE_DIAGNOSTIC:-false}" = "true" ]; then
      diagnostic_template=$benchmark_dir/aws_gnatprove_benchmark.gpr.in
      diagnostic_project=$results_dir/aws_gnatprove_benchmark.gpr
      sed "s|@AWS_SRC_PROJECT@|$project|" "$diagnostic_template" \
        >"$diagnostic_project"
      AWS_GNATPROVE_OBJECT_DIR=$results_dir/gnatprove-diagnostic-obj
      AWS_GNATPROVE_LIBRARY_DIR=$results_dir/gnatprove-diagnostic-lib
      export AWS_GNATPROVE_OBJECT_DIR AWS_GNATPROVE_LIBRARY_DIR
      status=0
      # shellcheck disable=SC2086
      /usr/bin/time -p -o "$results_dir/gnatprove-diagnostic-flow.time" \
        "$gnatprove" "-P$diagnostic_project" $scenario_args --mode=flow \
        -k --no-subprojects --output=brief --report=all \
        >"$results_dir/gnatprove-diagnostic-flow.stdout" \
        2>"$results_dir/gnatprove-diagnostic-flow.stderr" || status=$?
      printf '%s\n' "$status" \
        >"$results_dir/gnatprove-diagnostic-flow.status"
   fi
else
   echo "GNATprove lanes skipped: executable not found" >&2
fi

echo "AWS benchmark results written to $results_dir"
