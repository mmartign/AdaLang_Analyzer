#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
max_seconds=${ADALANG_MAX_SMOKE_SECONDS:-15}

start=$(date +%s)
status=0
"$analyzer" -q -checks='*' src/*.adb src/*.ads || status=$?
finish=$(date +%s)
elapsed=$((finish - start))

#  Exit status 1 is expected when the analyzer finds issues in its own source.
if [ "$status" -gt 1 ]; then
   echo "performance smoke analysis failed with status $status" >&2
   exit "$status"
fi

if [ "$elapsed" -gt "$max_seconds" ]; then
   echo "performance regression: ${elapsed}s exceeds ${max_seconds}s" >&2
   exit 1
fi

echo "performance smoke test passed in ${elapsed}s (limit ${max_seconds}s)"
