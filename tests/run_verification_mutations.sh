#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
manifest=quality/verification_mutations.tsv
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-verification-mutations.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

sed -n '/function Kind_Name/,/end Kind_Name/p' \
  src/adalang_analyzer-proof_obligations.adb |
  sed -n 's/^[[:space:]]*return "\([^"]*\)";.*/\1/p' |
  sort -u >"$work/expected-kinds"
awk -F '\t' '!/^#/ && NF {print $3}' "$manifest" |
  sort -u >"$work/mutation-kinds"
if ! cmp -s "$work/expected-kinds" "$work/mutation-kinds"; then
   echo "verification mutation manifest does not cover every obligation kind" >&2
   diff -u "$work/expected-kinds" "$work/mutation-kinds" >&2 || true
   exit 1
fi

tab=$(printf '\t')
count=0
while IFS="$tab" read -r id fixture kind operation expected_status note
do
   case "$id" in
      ''|'#'*) continue ;;
   esac

   output="$work/$id.json"
   status=0
   "$analyzer" --verify -q --format=json --output="$output" "$fixture" \
     >/dev/null 2>&1 || status=$?
   if [ "$status" -gt 1 ]; then
      echo "verification mutation run failed: $id ($fixture), status $status" >&2
      exit "$status"
   fi

   matching=$(grep -F "\"kind\": \"$kind\"" "$output" |
     grep -F "\"operation\": \"$operation\"" || true)
   if [ -z "$matching" ]; then
      echo "verification mutation obligation missing: $id" >&2
      echo "  fixture:   $fixture" >&2
      echo "  kind:      $kind" >&2
      echo "  operation: $operation" >&2
      echo "  note:      $note" >&2
      exit 1
   fi

   if printf '%s\n' "$matching" | grep -F '"status": "proved-safe"' >/dev/null; then
      echo "false-safe regression: mutation $id was proved safe" >&2
      echo "  note: $note" >&2
      exit 1
   fi
   if ! printf '%s\n' "$matching" |
     grep -F "\"status\": \"$expected_status\"" >/dev/null
   then
      echo "verification mutation outcome changed: $id" >&2
      echo "  expected: $expected_status" >&2
      printf '%s\n' "$matching" >&2
      exit 1
   fi

   count=$((count + 1))
done <"$manifest"

echo "verification mutation campaign: $count/$count seeded defects rejected"
