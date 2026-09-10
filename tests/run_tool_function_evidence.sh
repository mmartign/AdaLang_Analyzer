#!/bin/sh
set -eu

#  Tool-function validation-evidence gate.
#
#  quality/tool_function_evidence.tsv states, for every selectable check, its
#  documented function, its assurance class, the effect direction of a tool
#  malfunction (via the class), an independent oracle where one exists, and a
#  positive + negative validation invocation. This gate keeps that manifest
#  honest and regenerates the qualification-support document from it.
#
#  It checks:
#   1. the manifest lists exactly the Rule_Kind catalogue -- no missing check,
#      no stale row, no duplicate;
#   2. every row's class and independent-oracle value is from the fixed
#      vocabulary, and a claimed oracle is backed by the corresponding
#      evidence body (the GNATcheck comparison document, or the verification
#      obligation families the GNATprove differential exercises);
#   3. every positive invocation still produces a finding and every negative
#      invocation is still clean, run one check at a time (-checks="-*,<rule>");
#   4. docs/src/tool-qualification-support.md is exactly what
#      tests/gen_tool_qualification_doc.sh regenerates from the manifest.

analyzer=${ANALYZER:-./bin/adalang_analyzer}
rules=src/adalang_analyzer-rules.ads
manifest=quality/tool_function_evidence.tsv
gnatcheck_doc=docs/src/gnatcheck-rule-comparison.md
qual_doc=docs/src/tool-qualification-support.md
generator=tests/gen_tool_qualification_doc.sh

work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-tool-function-evidence.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

catalogue_rules="$work/catalogue-rules"
manifest_rules="$work/manifest-rules"

#  The Rule_Kind enumeration in rules.ads is the authoritative check
#  catalogue; scrape every literal between "type Rule_Kind is (" and its
#  closing ");".
sed -n '/type Rule_Kind is (/,/^   );/p' "$rules" |
  grep -oE '^ +[A-Z][A-Za-z0-9_]+' |
  tr -d ' ' |
  sort >"$catalogue_rules"

awk -F '\t' '!/^#/ && NF {print $1}' "$manifest" | sort >"$manifest_rules"

if ! cmp -s "$catalogue_rules" "$manifest_rules"; then
   echo "tool-function evidence manifest is out of sync with the Rule_Kind catalogue" >&2
   diff -u "$catalogue_rules" "$manifest_rules" >&2 || true
   exit 1
fi

if [ "$(wc -l <"$manifest_rules" | tr -d ' ')" -ne \
     "$(uniq "$manifest_rules" | wc -l | tr -d ' ')" ]; then
   echo "tool-function evidence manifest contains duplicate check rows" >&2
   uniq -d "$manifest_rules" >&2
   exit 1
fi

#  The verification-obligation families the clean/broken GNATprove differential
#  corpora exercise (see docs/src/assurance-model.md). A row may only claim the
#  gnatprove-differential oracle for a check in this set.
gnatprove_backed="
Division_By_Zero
Known_Overflow_Failure
Known_Range_Check_Failure
Known_Index_Check_Failure
Known_Precondition_Failure
Known_Postcondition_Failure
Known_Assertion_Failure
"

#  The 'Direct or close counterpart' section of the GNATcheck comparison is the
#  one whose rows the benchmarks/ GNATcheck oracle run actually cross-checks.
sed -n '/^## AdaLang rules with a direct or close/,/^## AdaLang rules that only partially/p' \
  "$gnatcheck_doc" >"$work/gnatcheck-directclose"

tab=$(printf '\t')
while IFS="$tab" read -r rule class function oracle finding_args clean_args; do
   case "$rule" in
      ''|'#'*) continue ;;
   esac

   case "$class" in
      policy|defect|known_failure|readiness|metric|style) ;;
      *) echo "check $rule has unknown class '$class'" >&2; exit 1 ;;
   esac

   if [ -z "$function" ]; then
      echo "check $rule has an empty documented-function cell" >&2
      exit 1
   fi

   case "$oracle" in
      none) ;;
      gnatcheck-comparison)
         if ! grep -qE "^\| $rule \|" "$work/gnatcheck-directclose"; then
            echo "check $rule claims the gnatcheck-comparison oracle but is not a Direct/Close row in $gnatcheck_doc" >&2
            exit 1
         fi ;;
      gnatprove-differential)
         if ! echo "$gnatprove_backed" | grep -qx "$rule"; then
            echo "check $rule claims the gnatprove-differential oracle but its obligation kind is not in the differential corpus" >&2
            exit 1
         fi ;;
      *) echo "check $rule has unknown independent oracle '$oracle'" >&2; exit 1 ;;
   esac

   #  Intentional word splitting: each argument column is the analyzer
   #  options/files it records. Fixture paths and options carry no whitespace.
   # shellcheck disable=SC2086
   if "$analyzer" -q -checks="-*,$rule" $finding_args; then
      echo "positive fixture did not trigger $rule: $finding_args" >&2
      exit 1
   fi

   # shellcheck disable=SC2086
   if ! "$analyzer" -q -checks="-*,$rule" $clean_args; then
      echo "negative fixture unexpectedly triggered $rule: $clean_args" >&2
      # shellcheck disable=SC2086
      "$analyzer" -checks="-*,$rule" $clean_args >&2 || true
      exit 1
   fi
done <"$manifest"

#  The published document must be a byte-exact regeneration of the manifest.
sh "$generator" >"$work/regenerated-doc"
if ! cmp -s "$work/regenerated-doc" "$qual_doc"; then
   echo "$qual_doc is stale; regenerate it with: sh $generator > $qual_doc" >&2
   diff -u "$qual_doc" "$work/regenerated-doc" >&2 || true
   exit 1
fi

echo "tool-function validation-evidence tests passed"
