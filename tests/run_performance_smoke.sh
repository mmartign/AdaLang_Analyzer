#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}

#  The workload is the analyzer's own source, which grows with every
#  release, so the default limit grows with it: 1.05 ms for each source
#  line, about half as much again as a run takes, and never under 15 s.
#  The figure was 0.55 ms while "-checks='*'" meant 127 checks; it covers
#  294 since the coding-standard checks were added, and those resolve
#  every name of sources analyzed here without their project.
lines=$(cat src/*.adb src/*.ads | wc -l)
default_seconds=$((lines * 105 / 100000))
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

#  A chain of 30 calls in prefix notation under --verify: about a second.
#  Each link was walked twice, once as the name of its call and once as
#  its first actual, so the time doubled with each link; Alire's lists of
#  switches (23 long) took half an hour each.
chain_limit=${ADALANG_MAX_CHAIN_SECONDS:-30}
start=$(date +%s)
status=0
"$analyzer" --verify -q tests/performance_call_chain.ads \
  tests/performance_call_chain.adb >/dev/null || status=$?
finish=$(date +%s)
elapsed=$((finish - start))
if [ "$status" -gt 1 ]; then
   echo "call-chain verification failed with status $status" >&2
   exit "$status"
fi
if [ "$elapsed" -gt "$chain_limit" ]; then
   echo "performance regression: a chain of 30 prefixed calls took" \
     "${elapsed}s under --verify (limit ${chain_limit}s)" >&2
   exit 1
fi
echo "call-chain verification passed in ${elapsed}s (limit ${chain_limit}s)"
