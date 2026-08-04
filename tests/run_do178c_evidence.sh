#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
matrix=DO178C_COMPLIANCE_MATRIX.md
manifest=quality/do178c_rule_evidence.tsv
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-do178c-evidence.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

core_rules="$work/core-rules"
levelc_rules="$work/levelc-rules"
levelab_rules="$work/levelab-rules"
preset_rules="$work/preset-rules"
matrix_rules="$work/matrix-rules"
manifest_rules="$work/manifest-rules"

#  Enable_DO_178C_Preset (adalang_analyzer-cli.adb) enables Core_Rules at
#  every level, plus Level_C_Rules at A-C, plus Level_AB_Rules at A-B, so
#  those three promoted, single-source-of-truth constants in rules.ads are
#  what this test scrapes -- each block ends at the blank line before the
#  next declaration.
sed -n '/DO_178C_Core_Rules : aliased constant Rule_List :=/,/^$/p' \
  src/adalang_analyzer-rules.ads |
  grep -o '[A-Z][A-Za-z0-9_]*' |
  grep -v -E '^(DO_178C_Core_Rules|Rule_List)$' |
  sort >"$core_rules"

sed -n '/DO_178C_Level_C_Rules : aliased constant Rule_List :=/,/^$/p' \
  src/adalang_analyzer-rules.ads |
  grep -o '[A-Z][A-Za-z0-9_]*' |
  grep -v -E '^(DO_178C_Level_C_Rules|Rule_List)$' |
  sort >"$levelc_rules"

sed -n '/DO_178C_Level_AB_Rules : aliased constant Rule_List :=/,/^$/p' \
  src/adalang_analyzer-rules.ads |
  grep -o '[A-Z][A-Za-z0-9_]*' |
  grep -v -E '^(DO_178C_Level_AB_Rules|Rule_List)$' |
  sort >"$levelab_rules"

sort "$core_rules" "$levelc_rules" "$levelab_rules" >"$preset_rules"

if [ "$(wc -l <"$preset_rules" | tr -d ' ')" -ne \
     "$(uniq "$preset_rules" | wc -l | tr -d ' ')" ]
then
   echo "a rule appears in more than one DO-178C tier in rules.ads" >&2
   uniq -d "$preset_rules" >&2
   exit 1
fi

#  Column 3 of the matrix table is the "DO-178C level(s)" cell (e.g.
#  "A, B, C, D"). Exact string match against each tier's own level set
#  catches a mislabeled row, not just a rule missing from the table
#  entirely -- stricter than the flat rule-name check below alone.
sed -n \
  's/^| [0-9][0-9]* | `\([^`]*\)` | A, B, C, D |.*/\1/p' \
  "$matrix" | sort >"$work/matrix-core"
sed -n \
  's/^| [0-9][0-9]* | `\([^`]*\)` | A, B, C |.*/\1/p' \
  "$matrix" | sort >"$work/matrix-levelc"
sed -n \
  's/^| [0-9][0-9]* | `\([^`]*\)` | A, B |.*/\1/p' \
  "$matrix" | sort >"$work/matrix-levelab"

if ! cmp -s "$core_rules" "$work/matrix-core"; then
   echo "matrix Core-tier (A, B, C, D) rows are out of sync with rules.ads" >&2
   diff -u "$core_rules" "$work/matrix-core" >&2 || true
   exit 1
fi

if ! cmp -s "$levelc_rules" "$work/matrix-levelc"; then
   echo "matrix Level C-tier (A, B, C) rows are out of sync with rules.ads" >&2
   diff -u "$levelc_rules" "$work/matrix-levelc" >&2 || true
   exit 1
fi

if ! cmp -s "$levelab_rules" "$work/matrix-levelab"; then
   echo "matrix Level A/B-tier (A, B) rows are out of sync with rules.ads" >&2
   diff -u "$levelab_rules" "$work/matrix-levelab" >&2 || true
   exit 1
fi

sed -n 's/^| [0-9][0-9]* | `\([^`]*\)`.*/\1/p' "$matrix" |
  sort >"$matrix_rules"

awk -F '\t' '!/^#/ && NF {print $1}' "$manifest" |
  sort >"$manifest_rules"

if ! cmp -s "$preset_rules" "$matrix_rules"; then
   echo "DO-178C matrix rule set is out of sync with the implemented preset" >&2
   diff -u "$preset_rules" "$matrix_rules" >&2 || true
   exit 1
fi

if ! cmp -s "$preset_rules" "$manifest_rules"; then
   echo "DO-178C evidence manifest is out of sync with the preset" >&2
   diff -u "$preset_rules" "$manifest_rules" >&2 || true
   exit 1
fi

if [ "$(wc -l <"$manifest_rules" | tr -d ' ')" -ne \
     "$(uniq "$manifest_rules" | wc -l | tr -d ' ')" ]
then
   echo "DO-178C evidence manifest contains duplicate rule rows" >&2
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
      echo "finding fixture did not trigger DO-178C rule $rule" >&2
      exit 1
   fi

   # shellcheck disable=SC2086
   if ! "$analyzer" -q -checks="-*,$rule" $clean_args
   then
      echo "clean fixture unexpectedly triggered DO-178C rule $rule" >&2
      # shellcheck disable=SC2086
      "$analyzer" -checks="-*,$rule" $clean_args >&2 || true
      exit 1
   fi
done <"$manifest"

echo "DO-178C matrix and per-rule evidence tests passed"
