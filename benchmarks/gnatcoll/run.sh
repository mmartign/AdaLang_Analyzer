#!/bin/sh
set -eu

benchmark_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$benchmark_dir/../.." && pwd)
gnatcoll_root=${GNATCOLL_ROOT:?set GNATCOLL_ROOT to the pinned AdaCore/gnatcoll-core checkout}
results_dir=${RESULTS_DIR:-$repository_root/benchmark-results/gnatcoll}
analyzer=${ANALYZER:-$repository_root/bin/adalang_analyzer}

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

#  gnatcoll_core.gpr's "with "gnatcoll_minimal.gpr";" has no directory
#  prefix, so it resolves through project-path search rather than a
#  relative path. This repository's own Alire environment already depends
#  on a released gnatcoll (it sits underneath Libadalang), so its installed
#  gnatcoll_minimal.gpr is already on GPR_PROJECT_PATH; prepending the
#  pinned checkout's own minimal/ and config/ directories here ensures the
#  pinned revision's own sources are what actually get analyzed and built,
#  not whatever released version happens to be installed for this
#  repository's own toolchain.
GPR_PROJECT_PATH="$gnatcoll_root/minimal:$gnatcoll_root/minimal/config:$gnatcoll_root/core/config${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
export GPR_PROJECT_PATH

project=$gnatcoll_root/core/gnatcoll_core.gpr
scenario_args="-XGNATCOLL_OS=$gnatcoll_os -XLIBRARY_TYPE=static"

mkdir -p "$results_dir"

#  The build is not strictly required for AdaLang (which only parses and
#  checks the sources, the same as every other benchmark here), but it
#  confirms the pinned revision is a genuinely buildable, ordinary Ada
#  project -- not a claim this benchmark otherwise depends on -- and
#  populates the object directory GNATprove's own lane below needs.
# shellcheck disable=SC2086
gprbuild -s -j0 -p -P"$project" $scenario_args >"$results_dir/gprbuild.stdout" \
  2>"$results_dir/gprbuild.stderr"

run_adalang () {
   lane=$1
   preset=$2
   status=0

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

if command -v jq >/dev/null 2>&1; then
   for lane in recommended spark verify; do
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
   status=0
   # shellcheck disable=SC2086
   /usr/bin/time -p -o "$results_dir/gnatprove-flow.time" \
     "$gnatprove" "-P$project" $scenario_args --mode=flow \
     --output=brief --report=all \
     >"$results_dir/gnatprove-flow.stdout" \
     2>"$results_dir/gnatprove-flow.stderr" || status=$?
   printf '%s\n' "$status" >"$results_dir/gnatprove-flow.status"
else
   echo "GNATprove lane skipped: executable not found" >&2
fi

echo "gnatcoll-core benchmark results written to $results_dir"
