#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
matrix=AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md
manifest=quality/automotive_rule_evidence.tsv
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-automotive-evidence.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

preset_rules="$work/preset-rules"
matrix_rules="$work/matrix-rules"
manifest_rules="$work/manifest-rules"

sed -n \
  '/Automotive_Rules : constant/,/^[[:space:]]*begin$/p' \
  src/adalang_analyzer-cli.adb |
  grep -o '[A-Z][A-Za-z0-9_]*' |
  grep -v -E '^(Automotive_Rules|Positive|Rule_Kind)$' |
  sort >"$preset_rules"

sed -n 's/^| [0-9][0-9]* | `\([^`]*\)`.*/\1/p' "$matrix" |
  sort >"$matrix_rules"

awk -F '\t' '!/^#/ && NF {print $1}' "$manifest" |
  sort >"$manifest_rules"

if ! cmp -s "$preset_rules" "$matrix_rules"; then
   echo "automotive matrix is out of sync with the implemented preset" >&2
   diff -u "$preset_rules" "$matrix_rules" >&2 || true
   exit 1
fi

if ! cmp -s "$preset_rules" "$manifest_rules"; then
   echo "automotive evidence manifest is out of sync with the preset" >&2
   diff -u "$preset_rules" "$manifest_rules" >&2 || true
   exit 1
fi

if [ "$(wc -l <"$manifest_rules" | tr -d ' ')" -ne \
     "$(uniq "$manifest_rules" | wc -l | tr -d ' ')" ]
then
   echo "automotive evidence manifest contains duplicate rule rows" >&2
   exit 1
fi

tab=$(printf '\t')
while IFS="$tab" read -r rule finding_args clean_args
do
   case "$rule" in
      ''|'#'*) continue ;;
   esac

   #  Intentional word splitting turns each manifest argument column into the
   #  analyzer options/files it records. Fixture paths and options may not
   #  contain whitespace.
   # shellcheck disable=SC2086
   if "$analyzer" -q -checks="-*,$rule" $finding_args
   then
      echo "finding fixture did not trigger automotive rule $rule" >&2
      exit 1
   fi

   # shellcheck disable=SC2086
   if ! "$analyzer" -q -checks="-*,$rule" $clean_args
   then
      echo "clean fixture unexpectedly triggered automotive rule $rule" >&2
      # shellcheck disable=SC2086
      "$analyzer" -checks="-*,$rule" $clean_args >&2 || true
      exit 1
   fi
done <"$manifest"

echo "automotive matrix and per-rule evidence tests passed"
