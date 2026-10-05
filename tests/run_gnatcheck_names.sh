#!/bin/sh
set -eu

#  GNATcheck rule names are accepted wherever a check name is. The names
#  the analyzer knows must be exactly the pairs of
#  benchmarks/gnatcheck_rule_map.tsv and of the configuration-paired table
#  of docs/src/gnatcheck-rule-comparison.md.

analyzer=${ANALYZER:-./bin/adalang_analyzer}
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-gnatcheck-names.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

"$analyzer" -list-checks >"$work/list"

#  check<TAB>rule, as the analyzer lists them
awk '
   /^  [A-Za-z0-9_]+ \[/ { check = $1 }
   /^    GNATcheck: /    { sub(/^    GNATcheck: /, ""); n = split($0, names, ", ")
                           for (i = 1; i <= n; i++) print check "\t" names[i] }
' "$work/list" | sort >"$work/listed"

#  check<TAB>rule, as the rule map and the comparison document pair them;
#  a "warnings:x" or "style_checks:x" pairing is a compiler letter, not a
#  rule name of its own
{
   awk -F'\t' 'NR > 1 && $1 !~ /^#/ && $2 !~ /:/ { print $1 "\t" $2 }' \
     benchmarks/gnatcheck_rule_map.tsv
   awk -F'|' '
      /^\| AdaLang rule \| GNATcheck rule \| Parameters \|/ { on = 1; next }
      on && /^\| ---/ { next }
      on && /^\|/ { check = $2; rule = $3
                    gsub(/[ `]/, "", check); gsub(/[ `]/, "", rule)
                    print check "\t" rule; next }
      on { on = 0 }
   ' docs/src/gnatcheck-rule-comparison.md
} | sort -u >"$work/paired"

if ! diff "$work/paired" "$work/listed" >"$work/diff"
then
   echo "GNATcheck names differ from the rule map and the comparison document" >&2
   echo "(< paired in the documents, > known to the analyzer):" >&2
   cat "$work/diff" >&2
   exit 1
fi

cat >"$work/sample.adb" <<'ADA'
procedure Sample (X : in out Integer) is
begin
   if X > 0 then
      null;
   end if;
   case X is
      when 1 => null;
      when others => X := 0;
   end case;
   goto Done;
   <<Done>>
   X := X + 1;
end Sample;
ADA

findings() {
   "$analyzer" "$@" "$work/sample.adb" 2>&1 | grep -o '\[[A-Za-z_]*\]$' | sort -u | tr '\n' ' '
}

expect() {
   wanted=$1
   shift
   actual=$(findings "$@")
   if [ "$actual" != "$wanted" ]
   then
      echo "GNATcheck names: $* reported '$actual', expected '$wanted'" >&2
      exit 1
   fi
}

#  A rule name selects its check, whatever the case, in every form a check
#  name is accepted in.
expect '[No_Goto] ' '-checks=-*,goto_statements'
expect '[No_Goto] ' '-checks=-*,Goto_Statements'
expect '[No_Goto] ' '-checks=-*' '+RGoto_Statements'
#  A rule that is several checks here selects them all.
expect '[Empty_If_Body] [Null_Case_Alternative] ' '-checks=-*,null_paths'
#  It can be taken away again, by either name.
expect '[Empty_If_Body] [Null_Case_Alternative] ' '-checks=-*,null_paths,goto_statements,-No_Goto'
expect '[No_Goto] ' '-checks=-*,null_paths,goto_statements,-null_paths'

#  A name that is neither a check nor a rule is still refused.
if "$analyzer" '-checks=-*,no_such_rule' "$work/sample.adb" >"$work/out" 2>&1
then
   echo "GNATcheck names: an unknown name was accepted" >&2
   exit 1
fi
grep -F "unknown check 'no_such_rule'" "$work/out" >/dev/null || {
   echo "GNATcheck names: an unknown name was not reported as such" >&2
   cat "$work/out" >&2
   exit 1
}

#  A check parameter can be given under the rule's name.
"$analyzer" '-checks=-*,maximum_parameters' -rule-param=maximum_parameters.n=0 \
  "$work/sample.adb" >"$work/out" 2>&1 || true
if grep -F "unknown" "$work/out" >/dev/null
then
   echo "GNATcheck names: a parameter under a rule name was refused" >&2
   cat "$work/out" >&2
   exit 1
fi

echo "GNATcheck names tests passed ($(grep -c '' "$work/listed") pairs)"
