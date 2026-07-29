#!/bin/sh
set -eu

issues=quality/known_analysis_issues.tsv
history=quality/release_metrics.csv
baseline=quality/recommended.baseline
obligations=src/adalang_analyzer-proof_obligations.ads

version=$(sed -n 's/^version = "\(.*\)"/\1/p' alire.toml)
false_positives=$(awk -F '\t' \
  '$1 !~ /^#/ && $2 == "false-positive" && $3 == "open" { count++ }
   END { print count + 0 }' "$issues")
false_negatives=$(awk -F '\t' \
  '$1 !~ /^#/ && $2 == "false-negative" && $3 == "open" { count++ }
   END { print count + 0 }' "$issues")
supported_constructs=$(
  sed -n '/type Obligation_Kind is/,/);/p' "$obligations" |
    grep -Ec '^[[:space:]]*[(]?[A-Z][A-Za-z_]+[,)]'
)
baseline_findings=$(grep -Ec '^[0-9a-f]{16}$' "$baseline")

expected="$version,$false_positives,$false_negatives,$supported_constructs,$baseline_findings"
recorded=$(tail -n 1 "$history")

if [ "$recorded" != "$expected" ]
then
   echo "quality metrics are stale" >&2
   echo "recorded: $recorded" >&2
   echo "current:  $expected" >&2
   exit 1
fi

echo "quality metrics verified: $expected"
