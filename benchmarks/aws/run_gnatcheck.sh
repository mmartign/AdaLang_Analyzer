#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
aws_root=${AWS_ROOT:?set AWS_ROOT to the pinned AdaCore/aws checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/aws}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}
rule_map=$repository_root/benchmarks/gnatcheck_rule_map.tsv

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
project=$aws_root/src/src.gpr
scenario_args="-XTGT_DIR=$target_dir -XPRJ_TARGET=$prj_target -XTARGET=$target"
scenario_args="$scenario_args -XPRJ_BUILD=Debug -XPRJ_XMLADA=Installed"
scenario_args="$scenario_args -XPRJ_LAL=Disabled -XPRJ_LDAP=Disabled"
scenario_args="$scenario_args -XSOCKET=std -XSSL_DYNAMIC=false"
scenario_args="$scenario_args -XLIBRARY_TYPE=static"

adalang_checks=$(awk -F'\t' 'NR>1 && $1!="No_Recursion"{print $1}' "$rule_map" | sort -u | tr '\n' ',' | sed 's/,$//')
gc_rule_args=$(awk -F'\t' 'NR>1 && $2!="recursive_subprograms"{print $2}' "$rule_map" | sort -u | awk '{printf "-r %s ", $0}')

#  Run the AdaLang lane FIRST, under this repository's own alr-exec
#  environment only. AWS's own dependency resolution needs
#  GPR_PROJECT_PATH pointing at its configured project_dir; sourcing
#  GNATCHECK_ENV before this point would leak the from-source GNATcheck
#  build's GPR_PROJECT_PATH in too (it carries its own trimmed
#  gnatcoll/xmlada .gpr stubs, built runtime-only -- see
#  project_gnatcheck_acquisition.md -- which silently shadow the full,
#  properly-configured ones AWS/AdaLang actually need and break project
#  loading with confusing "source file ... not found" errors).
GPR_PROJECT_PATH="$project_dir${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
export GPR_PROJECT_PATH

status=0
# shellcheck disable=SC2086
"$analyzer" "-P$project" $scenario_args "-checks=$adalang_checks" --format=json -q \
  --output="$results_dir/adalang-gnatcheck-compare.json" \
  2>"$results_dir/adalang-gnatcheck-compare.stderr" || status=$?
if [ "$status" -gt 1 ]; then
   echo "AdaLang gnatcheck-compare lane failed with status $status" >&2
   exit "$status"
fi

#  Only now bring in GNATcheck's own runtime environment (see
#  benchmarks/sparknacl/run_gnatcheck.sh for the availability and
#  rule-exclusion notes: recursive_subprograms crashes this from-source
#  build's global call-graph analysis; No_Pragma/Forbidden_Pragmas needs
#  an explicit configured pragma list not decided yet). Its own
#  GPR_PROJECT_PATH is prepended with AWS's project_dir again, since
#  sourcing GNATCHECK_ENV overwrites the variable rather than extending it.
if [ -n "${GNATCHECK_ENV:-}" ]; then
   # shellcheck disable=SC1090
   . "$GNATCHECK_ENV"
fi
GPR_PROJECT_PATH="$project_dir${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
export GPR_PROJECT_PATH

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
eval "\"\$gnatcheck\" -P\"\$project\" $scenario_args --show-rule $gc_rule_args" \
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
echo "AWS GNATcheck-oracle results written to $results_dir"
