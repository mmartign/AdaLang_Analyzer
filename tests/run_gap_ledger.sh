#!/bin/sh
set -eu

#  benchmarks/gnatprove_gap_ledger.py on a small made-up report and log:
#  every way a GNATprove check can end up in the ledger, once.

work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-gap-ledger.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

python3 benchmarks/gnatprove_gap_ledger.py \
  tests/gap_ledger/adalang-verify.json \
  tests/gap_ledger/gnatprove-prove.oneline \
  --name sample --rows "$work/rows.tsv" >"$work/report.md"

row() {
   #  the AdaLang outcome and reason of the check at file:line:column
   awk -F'\t' -v f="$1" -v l="$2" -v c="$3" \
     '$2 == f && $3 == l && $4 == c && $6 != "no check" {print $6 "|" $8 "|" $9}' \
     "$work/rows.tsv"
}

expect() {
   actual=$(row "$1" "$2" "$3")
   if [ "$actual" != "$4" ]
   then
      echo "gap ledger: $1:$2:$3 is '$actual', expected '$4'" >&2
      cat "$work/rows.tsv" >&2
      exit 1
   fi
}

#  Two checks on one line go to the obligations at their own columns.
expect a.adb 10 7 'proved|proved-safe|'
expect a.adb 10 20 'proved|unproved|bounds unknown'
expect a.adb 12 5 'proved|unsupported|outside subset'
#  No obligation: the same kind nearby, another kind near, nothing.
expect a.adb 14 5 'proved|no obligation here|same kind within 3 lines'
expect a.adb 20 5 'proved|no obligation here|same kind within 3 lines'
expect a.adb 25 5 'proved|no such obligation kind|'
#  A check GNATprove did not prove that AdaLang proves is a disagreement.
expect a.adb 30 5 'not proved|proved-safe|'
#  A different column on the same line still pairs when it is the only one.
expect a.adb 40 9 'proved|proved-safe|'
#  A check repeated for two instances is one check; a continuation line
#  and a warning are not checks.
expect g.adb 5 3 'proved|unproved|contract transfer'
expect lib.ads 3 4 'proved|file without any obligation|'
#  Ten checks, the one obligation GNATprove has no check for, a header.
if [ "$(grep -c '' "$work/rows.tsv")" -ne 12 ]
then
   echo "gap ledger: expected 10 checks, 1 obligation without a check and a header" >&2
   cat "$work/rows.tsv" >&2
   exit 1
fi

grep -F 'GNATprove reports 10 checks (11 messages' "$work/report.md" >/dev/null || {
   echo "gap ledger: generic instances were not merged" >&2
   cat "$work/report.md" >&2
   exit 1
}
grep -F 'AdaLang proved, GNATprove did not: 1' "$work/report.md" >/dev/null || {
   echo "gap ledger: the disagreement was not reported" >&2
   cat "$work/report.md" >&2
   exit 1
}

echo "gap ledger tests passed"
