#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
coap_spark_root=${COAP_SPARK_ROOT:?set COAP_SPARK_ROOT to the pinned mgrojo/coap_spark checkout}
sparklib_root=${COAP_SPARK_SPARKLIB:?set COAP_SPARK_SPARKLIB to a deployed \`alr get sparklib=16.1.0\` crate directory (see README.md)}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/coap_spark}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}
rule_map=$repository_root/benchmarks/gnatcheck_rule_map.tsv

if [ "${ALIRE:-}" != "True" ]; then
   exec alr exec -- "$0" "$@"
fi

expected_coap_spark=$(sed -n '1p' "$benchmark_dir/COAP_SPARK_REVISION")
expected_wolfssl=$(sed -n '2p' "$benchmark_dir/COAP_SPARK_REVISION")
actual_coap_spark=$(git -C "$coap_spark_root" rev-parse HEAD)
actual_wolfssl=$(git -C "$coap_spark_root/libs/wolfssl" rev-parse HEAD)

if [ "$actual_coap_spark" != "$expected_coap_spark" ]; then
   echo "coap_spark revision mismatch: expected $expected_coap_spark, found $actual_coap_spark" >&2
   exit 1
fi
if [ "$actual_wolfssl" != "$expected_wolfssl" ]; then
   echo "wolfssl submodule revision mismatch: expected $expected_wolfssl, found $actual_wolfssl" >&2
   exit 1
fi

if [ ! -f "$coap_spark_root/config/coap_spark_config.gpr" ]; then
   echo "coap_spark is not configured: run 'alr build --stop-after=generation' in $coap_spark_root first" >&2
   echo "see benchmarks/coap_spark/README.md" >&2
   exit 1
fi
if [ ! -f "$sparklib_root/sparklib.gpr" ]; then
   echo "COAP_SPARK_SPARKLIB ($sparklib_root) has no sparklib.gpr -- run 'alr get sparklib=16.1.0' first" >&2
   echo "see benchmarks/coap_spark/README.md" >&2
   exit 1
fi
mkdir -p "$sparklib_root/sparklib_lib" "$sparklib_root/sparklib_obj"

#  Environment-drift fix beyond what README.md documents: on this machine's
#  current alr/gpr2 versions, GNAT project "with" resolution for a
#  directory-less name ("with \"sparklib.gpr\";") checks the with-ing
#  project's OWN directory before ever consulting GPR_PROJECT_PATH --
#  confirmed by direct experiment (gprls/adalang_analyzer both fail
#  identically, deterministically, with GPR_PROJECT_PATH set exactly per
#  README.md's documented override). Since coap_spark_root itself already
#  contains its own sparklib.gpr (the broken 14.1.1-era wrapper), it always
#  wins over the sparklib_root override regardless of GPR_PROJECT_PATH
#  order, and coap_spark.gpr fails to load ("extended project file
#  sparklib_external.gpr not found") every time -- not the intermittent
#  behavior README.md's "Toolchain override" section implies. Since
#  coap_spark_root is a throwaway /private/tmp clone (not this repository,
#  and not benchmarks/aws or benchmarks/sparknacl), the pinned checkout's
#  own sparklib.gpr is moved aside once so the "with" clause has nothing
#  local to find and must fall through to GPR_PROJECT_PATH's override --
#  idempotent (skipped if already moved), and does not touch this
#  repository or any protected benchmark file.
if [ -f "$coap_spark_root/sparklib.gpr" ]; then
   mv "$coap_spark_root/sparklib.gpr" "$coap_spark_root/sparklib.gpr.orig"
fi

mkdir -p "$results_dir"
project=$coap_spark_root/coap_spark.gpr
scenario_args="-XSPARKLIB_INSTALLED=False"

adalang_checks=$(awk -F'\t' 'NR>1 && $1!="No_Recursion"{print $1}' "$rule_map" | sort -u | tr '\n' ',' | sed 's/,$//')
gc_rule_args=$(awk -F'\t' 'NR>1 && $2!="recursive_subprograms"{print $2}' "$rule_map" | sort -u | awk '{printf "-r %s ", $0}')

#  Run the AdaLang lane FIRST, under this repository's own alr-exec
#  environment only, with the same SPARKlib-16.1.0-override
#  GPR_PROJECT_PATH benchmarks/coap_spark/run.sh uses (see
#  README.md's "Toolchain override" section for why coap_spark's own
#  bundled sparklib.gpr wrapper cannot be used unmodified with this
#  benchmark suite's FSF 16.1.0 toolchain). Sourcing GNATCHECK_ENV before
#  this point would leak the from-source GNATcheck build's own trimmed,
#  runtime-only GPR_PROJECT_PATH in ahead of this override, the same
#  failure mode documented in benchmarks/aws/run_gnatcheck.sh.
GPR_PROJECT_PATH="$sparklib_root${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
GPR_PROJECT_PATH="$GPR_PROJECT_PATH:$coap_spark_root:$coap_spark_root/libs/wolfssl/wrapper/Ada"
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
#  prepended with the SPARKlib override and coap_spark's own dirs again,
#  since sourcing GNATCHECK_ENV overwrites the variable rather than
#  extending it, and the override must keep winning over gnatcheck's
#  internal, runtime-only stubs.
if [ -n "${GNATCHECK_ENV:-}" ]; then
   # shellcheck disable=SC1090
   . "$GNATCHECK_ENV"
fi
GPR_PROJECT_PATH="$sparklib_root${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
GPR_PROJECT_PATH="$GPR_PROJECT_PATH:$coap_spark_root:$coap_spark_root/libs/wolfssl/wrapper/Ada"
export GPR_PROJECT_PATH

gnatcheck=${GNATCHECK:-}
if [ -z "$gnatcheck" ]; then
   gnatcheck=$(command -v gnatcheck || true)
fi
if [ -z "$gnatcheck" ]; then
   echo "GNATcheck lane skipped: executable not found (set GNATCHECK or GNATCHECK_ENV)" >&2
   exit 1
fi

#  Same reasoning as benchmarks/cubedos/run_gnatcheck.sh: keep this run's
#  rule set exactly the shared map's rather than any project-embedded
#  GNATcheck configuration coap_spark.gpr might carry.
status=0
# shellcheck disable=SC2086
eval "\"\$gnatcheck\" -P\"\$project\" $scenario_args --ignore-project-switches --show-rule $gc_rule_args" \
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
echo "coap_spark GNATcheck-oracle results written to $results_dir"
