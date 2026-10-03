#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}

#  The workload is the analyzer's own source, which grows with every
#  release, so the default limit grows with it: 0.55 ms for each source
#  line, about half as much again as a run takes, and never under 15 s.
lines=$(cat src/*.adb src/*.ads | wc -l)
default_seconds=$((lines * 55 / 100000))
if [ "$default_seconds" -lt 15 ]; then
   default_seconds=15
fi
max_seconds=${ADALANG_MAX_SMOKE_SECONDS:-$default_seconds}

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
