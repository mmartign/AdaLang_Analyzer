#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
gnatcoll_root=${GNATCOLL_ROOT:?set GNATCOLL_ROOT to the pinned AdaCore/gnatcoll-core checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/gnatcoll}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}
rule_map=$repository_root/benchmarks/gnatcheck_rule_map.tsv

if [ "${ALIRE:-}" != "True" ]; then
   exec alr exec -- "$0" "$@"
fi

expected_gnatcoll=$(sed -n '1p' "$benchmark_dir/GNATCOLL_REVISION")
actual_gnatcoll=$(git -C "$gnatcoll_root" rev-parse HEAD)
if [ "$actual_gnatcoll" != "$expected_gnatcoll" ]; then
   echo "gnatcoll-core revision mismatch: expected $expected_gnatcoll, found $actual_gnatcoll" >&2
   exit 1
fi

case $(uname -s) in
   Darwin) default_os=osx ;;
   *) default_os=unix ;;
esac
gnatcoll_os=${GNATCOLL_OS:-$default_os}

mkdir -p "$results_dir"
project=$gnatcoll_root/core/gnatcoll_core.gpr
scenario_args="-XGNATCOLL_OS=$gnatcoll_os -XLIBRARY_TYPE=static"

adalang_checks=$(awk -F'\t' 'NR>1 && $1!="No_Recursion"{print $1}' "$rule_map" | sort -u | tr '\n' ',' | sed 's/,$//')
gc_rule_args=$(awk -F'\t' 'NR>1 && $2!="recursive_subprograms"{print $2}' "$rule_map" | sort -u | awk '{printf "-r %s ", $0}')

#  Run the AdaLang lane FIRST, under this repository's own alr-exec
#  environment only, with the pinned checkout's own minimal/ and config/
#  directories prepended to GPR_PROJECT_PATH exactly as run.sh does (see
#  benchmarks/gnatcoll/README.md's "Why GPR_PROJECT_PATH is set explicitly"
#  section): this repository's own Alire environment already depends on a
#  released gnatcoll crate, so without this the pinned checkout's
#  gnatcoll_core.gpr could silently resolve "with gnatcoll_minimal.gpr"
#  against that different, already-installed project instead of the pinned
#  revision's own. Sourcing GNATCHECK_ENV before this point would also leak
#  the from-source GNATcheck build's own trimmed, runtime-only
#  gnatcoll_core.gpr/xmlada*.gpr stubs in ahead of either of those --
#  see benchmarks/aws/run_gnatcheck.sh's comment for the failure mode this
#  caused there.
GPR_PROJECT_PATH="$gnatcoll_root/minimal:$gnatcoll_root/minimal/config:$gnatcoll_root/core/config${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
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
#  build's global call-graph analysis). Its own GPR_PROJECT_PATH is
#  prepended with the pinned checkout's own minimal/config dirs again,
#  since sourcing GNATCHECK_ENV overwrites the variable rather than
#  extending it.
if [ -n "${GNATCHECK_ENV:-}" ]; then
   # shellcheck disable=SC1090
   . "$GNATCHECK_ENV"
fi
GPR_PROJECT_PATH="$gnatcoll_root/minimal:$gnatcoll_root/minimal/config:$gnatcoll_root/core/config${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
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
echo "gnatcoll-core GNATcheck-oracle results written to $results_dir"
