#!/bin/sh
set -eu

#  Corpus exercise-coverage gate.
#
#  quality/corpus_exercise_coverage.tsv records, per Rule_Kind check, whether
#  a committed benchmark preset run enabled it over an external corpus, and
#  how many findings across how many files it produced there. It is derived
#  wholly from benchmark-results/*/adalang-*.json by
#  tests/gen_corpus_exercise_coverage.py.
#
#  This gate regenerates the file and fails if the committed copy is stale or
#  no longer covers the whole catalogue. Like the GNATprove differential, it
#  skips (exit 0) when its optional dependency -- here python3 -- is absent,
#  so the pure-sh suite still runs on a minimal host.

rules=src/adalang_analyzer-rules.ads
coverage=quality/corpus_exercise_coverage.tsv
generator=tests/gen_corpus_exercise_coverage.py

if ! command -v python3 >/dev/null 2>&1; then
   echo "corpus exercise-coverage gate skipped: python3 not available"
   exit 0
fi

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

python3 "$generator" >"$work/regenerated"
if ! cmp -s "$work/regenerated" "$coverage"; then
   echo "$coverage is stale; regenerate it with: python3 $generator > $coverage" >&2
   diff -u "$coverage" "$work/regenerated" >&2 || true
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

echo "corpus exercise-coverage tests passed"
