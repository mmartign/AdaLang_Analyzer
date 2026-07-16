#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
checks='Contradictory_Condition,Identical_Branches,Repeated_Statement,Ineffective_Operation,Constant_Result_Operation,Empty_Loop,Unreachable_Code'
output=$(mktemp "${TMPDIR:-/tmp}/adalang-findings.XXXXXX")
trap 'rm -f "$output"' EXIT HUP INT TERM

if "$analyzer" -checks="$checks" tests/bug_findings.adb >"$output" 2>&1; then
   echo "expected bug_findings.adb to produce violations" >&2
   exit 1
fi

for rule in \
   Contradictory_Condition \
   Identical_Branches \
   Repeated_Statement \
   Ineffective_Operation \
   Constant_Result_Operation \
   Empty_Loop \
   Unreachable_Code
do
   if ! grep -F "[$rule]" "$output" >/dev/null; then
      echo "missing expected finding: $rule" >&2
      exit 1
   fi
done

if ! "$analyzer" -q -checks="$checks" tests/clean_findings.adb; then
   echo "clean_findings.adb unexpectedly produced a violation" >&2
   exit 1
fi

high_value_checks='No_Unchecked_Conversion,Floating_Equality,Magic_Number'
if "$analyzer" -checks="$high_value_checks" \
     tests/high_value_findings.adb >"$output" 2>&1
then
   echo "expected high_value_findings.adb to produce violations" >&2
   exit 1
fi

for rule in No_Unchecked_Conversion Floating_Equality Magic_Number
do
   if ! grep -F "[$rule]" "$output" >/dev/null; then
      echo "missing expected finding: $rule" >&2
      exit 1
   fi
done

if ! "$analyzer" -q -checks="$high_value_checks" tests/high_value_clean.adb; then
   echo "high_value_clean.adb unexpectedly produced a violation" >&2
   exit 1
fi

advanced_checks='Unused_Parameter,Dead_Store,Overwritten_Assignment,Shadowed_Declaration,Unreachable_Case_Alternative,Overlapping_Case_Ranges,Infinite_Loop,Duplicate_Boolean_Operand,Exception_Swallowed,Cyclomatic_Complexity'
if "$analyzer" -complexity-threshold=2 -checks="$advanced_checks" \
     tests/advanced_findings.adb >"$output" 2>&1
then
   echo "expected advanced_findings.adb to produce violations" >&2
   exit 1
fi

for rule in \
   Unused_Parameter \
   Dead_Store \
   Overwritten_Assignment \
   Shadowed_Declaration \
   Unreachable_Case_Alternative \
   Overlapping_Case_Ranges \
   Infinite_Loop \
   Duplicate_Boolean_Operand \
   Exception_Swallowed \
   Cyclomatic_Complexity
do
   if ! grep -F "[$rule]" "$output" >/dev/null; then
      echo "missing expected finding: $rule" >&2
      cat "$output" >&2
      exit 1
   fi
done

if ! "$analyzer" -q -complexity-threshold=20 \
     -checks="$advanced_checks" tests/advanced_clean.adb
then
   echo "advanced_clean.adb unexpectedly produced a violation" >&2
   exit 1
fi

new_checks='No_Recursion,No_Multiple_Return,Non_Short_Circuit_Condition,Address_Clause,Too_Many_Parameters,Deep_Nesting,Unused_Variable,Empty_If_Body,Unnecessary_Else_After_Return,Function_Side_Effect,Redundant_Boolean_Comparison,Long_Line,Trailing_Whitespace'
new_checks_opts='-parameter-threshold=3 -nesting-threshold=3 -line-length-threshold=80'
if "$analyzer" $new_checks_opts -checks="$new_checks" \
     tests/new_checks_findings.adb >"$output" 2>&1
then
   echo "expected new_checks_findings.adb to produce violations" >&2
   exit 1
fi

for rule in \
   No_Recursion \
   No_Multiple_Return \
   Non_Short_Circuit_Condition \
   Address_Clause \
   Too_Many_Parameters \
   Deep_Nesting \
   Unused_Variable \
   Empty_If_Body \
   Unnecessary_Else_After_Return \
   Function_Side_Effect \
   Redundant_Boolean_Comparison \
   Long_Line \
   Trailing_Whitespace
do
   if ! grep -F "[$rule]" "$output" >/dev/null; then
      echo "missing expected finding: $rule" >&2
      cat "$output" >&2
      exit 1
   fi
done

if ! "$analyzer" -q $new_checks_opts -checks="$new_checks" \
     tests/new_checks_clean.adb
then
   echo "new_checks_clean.adb unexpectedly produced a violation" >&2
   "$analyzer" $new_checks_opts -checks="$new_checks" tests/new_checks_clean.adb >&2 || true
   exit 1
fi

flow_checks='Division_By_Zero,Constant_Condition'
if "$analyzer" -checks="$flow_checks" tests/flow_findings.adb >"$output" 2>&1
then
   echo "expected flow_findings.adb to produce violations" >&2
   exit 1
fi

for rule in Division_By_Zero Constant_Condition
do
   if ! grep -F "[$rule]" "$output" >/dev/null; then
      echo "missing expected finding: $rule" >&2
      cat "$output" >&2
      exit 1
   fi
done

if ! "$analyzer" -q -checks="$flow_checks" tests/flow_clean.adb; then
   echo "flow_clean.adb unexpectedly produced a violation" >&2
   "$analyzer" -checks="$flow_checks" tests/flow_clean.adb >&2 || true
   exit 1
fi

echo "bug-finding regression tests passed"
