#!/bin/sh
set -eu

#  Corpus exercise-coverage gate.
#
#  quality/corpus_exercise_coverage.tsv records, per Rule_Kind check, whether
#  a committed benchmark preset run enabled it over an external corpus, and
#  how many findings across how many files it produced there. It is a release
#  snapshot: tests/gen_corpus_exercise_coverage.py regenerates it from
#  benchmark-results/*/adalang-*.json, which -- like the rest of
#  benchmark-results/ -- is gitignored and only present after a local
#  benchmark run. It is refreshed alongside the benchmarks/*/RESULTS_*.md
#  files.
#
#  This gate always checks the file's structure (whole catalogue, one row per
#  check, fixed column shapes). It additionally regenerates and diffs the
#  file only when the benchmark result JSON is present locally, so a fresh
#  checkout or CI -- where benchmark-results/ does not exist -- still passes.

rules=src/adalang_analyzer-rules.ads
coverage=quality/corpus_exercise_coverage.tsv
generator=tests/gen_corpus_exercise_coverage.py
results_dir=benchmark-results

work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-corpus-coverage.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

catalogue_rules="$work/catalogue-rules"
coverage_rules="$work/coverage-rules"

sed -n '/type Rule_Kind is (/,/^   );/p' "$rules" |
  grep -oE '^ +[A-Z][A-Za-z0-9_]+' |
  tr -d ' ' |
  sort >"$catalogue_rules"

awk -F '\t' '!/^#/ && NF {print $1}' "$coverage" | sort >"$coverage_rules"

if ! cmp -s "$catalogue_rules" "$coverage_rules"; then
   echo "$coverage is out of sync with the Rule_Kind catalogue" >&2
   diff -u "$catalogue_rules" "$coverage_rules" >&2 || true
   exit 1
fi

if [ "$(wc -l <"$coverage_rules" | tr -d ' ')" -ne \
     "$(uniq "$coverage_rules" | wc -l | tr -d ' ')" ]; then
   echo "$coverage contains duplicate check rows" >&2
   exit 1
fi

#  Every column past the check name has a fixed shape.
awk -F '\t' '
  !/^#/ && NF {
     if ($2 != "yes" && $2 != "no") { print "bad exercised value: " $0 > "/dev/stderr"; bad = 1 }
     if ($2 == "no" && ($3 != "-" || $4 != "0")) { print "no-row must have empty presets and 0 corpora: " $0 > "/dev/stderr"; bad = 1 }
     if ($2 == "yes" && ($3 == "-" || $4 + 0 < 1)) { print "yes-row must name presets and >=1 corpus: " $0 > "/dev/stderr"; bad = 1 }
     if ($4 !~ /^[0-9]+$/ || $5 !~ /^[0-9]+$/ || $6 !~ /^[0-9]+$/) { print "non-numeric count: " $0 > "/dev/stderr"; bad = 1 }
     if ($6 + 0 > $5 + 0) { print "files exceeds findings: " $0 > "/dev/stderr"; bad = 1 }
  }
  END { exit bad ? 1 : 0 }
' "$coverage"

#  The "# corpora scanned (N): ..." header the doc generator reads must be present.
if ! grep -qE '^# corpora scanned \([0-9]+\):' "$coverage"; then
   echo "$coverage is missing its '# corpora scanned' header" >&2
   exit 1
fi

if command -v python3 >/dev/null 2>&1 &&
   ls "$results_dir"/*/adalang-*.json >/dev/null 2>&1
then
   python3 "$generator" >"$work/regenerated"
   if ! cmp -s "$work/regenerated" "$coverage"; then
      echo "$coverage is stale against the local benchmark results;" \
           "regenerate it with: python3 $generator > $coverage" >&2
      diff -u "$coverage" "$work/regenerated" >&2 || true
      exit 1
   fi
   echo "corpus exercise-coverage tests passed (verified against local benchmark results)"
else
   echo "corpus exercise-coverage tests passed (structure only; benchmark-results/ not present)"
fi
