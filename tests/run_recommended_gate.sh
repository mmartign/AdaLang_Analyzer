#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
baseline=${RECOMMENDED_BASELINE:-quality/recommended.baseline}

if [ ! -f "$baseline" ]
then
   echo "recommended baseline not found: $baseline" >&2
   exit 1
fi

"$analyzer" -q --recommended --baseline="$baseline" src/*.adb src/*.ads

echo "recommended self-analysis gate passed"
