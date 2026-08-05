#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
output=$(mktemp "${TMPDIR:-/tmp}/adalang-circular.XXXXXX")
trap 'rm -f "$output"' EXIT HUP INT TERM

#  Circular_Package_Dependency is a whole-program check: the cycle only
#  exists across the with-graph of every analyzed file, so it must be
#  exercised with all of a cycle's files given on the same command line
#  (a single-file run can never see it).
if "$analyzer" -checks='Circular_Package_Dependency' \
     tests/circular_dependency_findings_a.ads \
     tests/circular_dependency_findings_b.ads \
     tests/circular_dependency_clean.ads >"$output" 2>&1
then
   echo "expected the mutual with cycle to produce a violation" >&2
   exit 1
fi
if [ "$(grep -c '\[Circular_Package_Dependency\]' "$output")" -ne 1 ] \
  || ! grep -F \
       "circular_dependency_findings_a.ads:1:1: warning:" "$output" \
       >/dev/null \
  || ! grep -F \
       "circular dependency: circular_dependency_findings_a.ads -> circular_dependency_findings_b.ads -> circular_dependency_findings_a.ads" \
       "$output" >/dev/null
then
   echo "unexpected circular-dependency findings" >&2
   cat "$output" >&2
   exit 1
fi

if ! "$analyzer" -q -checks='Circular_Package_Dependency' \
     tests/circular_dependency_clean.ads
then
   echo "circular_dependency_clean.ads unexpectedly produced a violation" >&2
   exit 1
fi

#  A cycle's files given without any of their cycle partners on the command
#  line cannot possibly be flagged: the with-graph is only built over the
#  files actually being analyzed in this run.
if ! "$analyzer" -q -checks='Circular_Package_Dependency' \
     tests/circular_dependency_findings_a.ads
then
   echo "single cycle member analyzed alone unexpectedly produced a violation" >&2
   exit 1
fi

#  A "limited with" gives only an incomplete view and imposes no
#  "elaborate before" requirement, so two units that reference each other
#  through one ordinary with and one limited with (Ada's own sanctioned way
#  to let mutually-referential units avoid a real circular dependency) must
#  not be flagged (FP-042).
if ! "$analyzer" -q -checks='Circular_Package_Dependency' \
     tests/circular_dependency_limited_with_a.ads \
     tests/circular_dependency_limited_with_b.ads
then
   echo "limited-with pair unexpectedly produced a violation" >&2
   exit 1
fi

echo "circular-dependency tests passed"
