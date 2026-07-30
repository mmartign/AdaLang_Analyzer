#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
manifest=quality/precision_corpus.tsv
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-precision-corpus.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

case_ids="$work/case-ids"
awk -F '\t' '!/^#/ && NF {print $1 "\t" $2}' "$manifest" | sort >"$case_ids"
if [ "$(wc -l <"$case_ids" | tr -d ' ')" -ne \
     "$(uniq "$case_ids" | wc -l | tr -d ' ')" ]
then
   echo "precision corpus manifest contains duplicate (rule, case) rows" >&2
   exit 1
fi

count=0
tab=$(printf '\t')
while IFS="$tab" read -r rule case fixture expected note
do
   case "$rule" in
      ''|'#'*) continue ;;
   esac

   if "$analyzer" -q -checks="-*,$rule" "$fixture"
   then
      actual=clean
   else
      actual=finding
   fi

   if [ "$actual" != "$expected" ]
   then
      echo "precision corpus mismatch: $rule/$case ($fixture)" >&2
      echo "  expected: $expected" >&2
      echo "  actual:   $actual" >&2
      echo "  note:     $note" >&2
      "$analyzer" -checks="-*,$rule" "$fixture" >&2 || true
      exit 1
   fi

   count=$((count + 1))
done <"$manifest"

echo "precision corpus: $count/$count cases verified"
