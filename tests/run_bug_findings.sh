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

#  Semantic lookup must use the paths supplied to the analyzer, rather than
#  assuming that sibling units live in the process working directory.  Keep
#  the body first to match shell glob ordering in the original regression.
provider_checks='Floating_Equality,Overwritten_Assignment'
if "$analyzer" -checks="$provider_checks" \
     tests/provider_path_findings.adb \
     tests/provider_path_findings.ads >"$output" 2>&1
then
   echo "expected provider_path_findings.adb to produce violations" >&2
   exit 1
fi

for rule in Floating_Equality Overwritten_Assignment
do
   if ! grep -F "[$rule]" "$output" >/dev/null; then
      echo "missing path-independent semantic finding: $rule" >&2
      cat "$output" >&2
      exit 1
   fi
done

if [ "$(grep -c '\[Overwritten_Assignment\]' "$output")" -ne 1 ] \
  || ! grep -F \
       "provider_path_findings.adb:8:7: warning:" "$output" >/dev/null
then
   echo "overwritten assignment must identify only the earlier wasted write" >&2
   cat "$output" >&2
   exit 1
fi

precision_checks='Dead_Store,Overwritten_Assignment'
if "$analyzer" -checks="$precision_checks" \
     tests/data_flow_precision_findings.adb >"$output" 2>&1
then
   echo "expected data_flow_precision_findings.adb to produce violations" >&2
   exit 1
fi

if [ "$(grep -c '\[Dead_Store\]' "$output")" -ne 3 ] \
  || [ "$(grep -c '\[Overwritten_Assignment\]' "$output")" -ne 2 ] \
  || ! grep -F \
       "data_flow_precision_findings.adb:17:4: warning:" "$output" >/dev/null \
  || ! grep -F \
       "data_flow_precision_findings.adb:19:4: warning:" "$output" >/dev/null \
  || ! grep -F \
       "data_flow_precision_findings.adb:21:4: warning:" "$output" >/dev/null
then
   echo "unexpected nested-read or array-component data-flow findings" >&2
   cat "$output" >&2
   exit 1
fi

parameter_mode_checks='Wrong_Parameter_Mode,Dead_Store'
if "$analyzer" -checks="$parameter_mode_checks" \
     tests/parameter_mode_findings.adb >"$output" 2>&1
then
   echo "expected parameter_mode_findings.adb to produce violations" >&2
   exit 1
fi

if [ "$(grep -c '\[Wrong_Parameter_Mode\]' "$output")" -ne 2 ] \
  || [ "$(grep -c '\[Dead_Store\]' "$output")" -ne 0 ]
then
   echo "unexpected parameter-mode findings" >&2
   cat "$output" >&2
   exit 1
fi

if ! "$analyzer" -q -checks="$parameter_mode_checks" \
     tests/parameter_mode_clean.adb
then
   echo "parameter_mode_clean.adb unexpectedly produced a violation" >&2
   "$analyzer" -checks="$parameter_mode_checks" \
     tests/parameter_mode_clean.adb >&2 || true
   exit 1
fi

call_checks='Self_Assignment,Dead_Store,Unused_Variable'
if "$analyzer" -checks="$call_checks" \
     tests/call_and_rename_findings.adb >"$output" 2>&1
then
   echo "expected call_and_rename_findings.adb to produce violations" >&2
   exit 1
fi

if [ "$(grep -c '\[Self_Assignment\]' "$output")" -ne 1 ] \
  || [ "$(grep -c '\[Dead_Store\]' "$output")" -ne 1 ] \
  || [ "$(grep -c '\[Unused_Variable\]' "$output")" -ne 0 ] \
  || ! grep -F \
       "call_and_rename_findings.adb:19:4: warning:" "$output" >/dev/null \
  || ! grep -F \
       "call_and_rename_findings.adb:25:10: warning:" "$output" >/dev/null
then
   echo "unexpected rename or call-output data-flow findings" >&2
   cat "$output" >&2
   exit 1
fi

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

spark_checks='SPARK_Mode,Constant_Condition,Division_By_Zero,Known_Precondition_Failure,Known_Postcondition_Failure'
if "$analyzer" -checks="$spark_checks" tests/spark_findings.adb \
     >"$output" 2>&1
then
   echo "expected spark_findings.adb to produce violations" >&2
   exit 1
fi

for rule in \
   SPARK_Mode \
   Constant_Condition \
   Division_By_Zero \
   Known_Precondition_Failure \
   Known_Postcondition_Failure
do
   if ! grep -F "[$rule]" "$output" >/dev/null; then
      echo "missing expected SPARK finding: $rule" >&2
      cat "$output" >&2
      exit 1
   fi
done

if [ "$(grep -c '\[Known_Precondition_Failure\]' "$output")" -ne 1 ] \
  || [ "$(grep -c '\[Known_Postcondition_Failure\]' "$output")" -ne 1 ]
then
   echo "unexpected duplicate or disabled-region contract finding" >&2
   cat "$output" >&2
   exit 1
fi

if "$analyzer" --spark tests/spark_findings.adb >"$output" 2>&1; then
   echo "the SPARK preset unexpectedly found no violations" >&2
   exit 1
fi

for rule in Known_Precondition_Failure Known_Postcondition_Failure
do
   if ! grep -F "[$rule]" "$output" >/dev/null; then
      echo "the --spark preset is missing $rule" >&2
      cat "$output" >&2
      exit 1
   fi
done

if ! "$analyzer" -q -checks="$spark_checks" tests/spark_clean.adb; then
   echo "spark_clean.adb retained stale state across a contracted call" >&2
   "$analyzer" -checks="$spark_checks" tests/spark_clean.adb >&2 || true
   exit 1
fi

if ! "$analyzer" --help | grep -F -- '--spark' >/dev/null; then
   echo "--spark is missing from command help" >&2
   exit 1
fi

spark_readiness_checks='Missing_Global_Contract,Global_Contract_Mismatch,Missing_Depends_Contract,Incomplete_Depends_Contract,Uninitialized_Output'
if "$analyzer" -checks="$spark_readiness_checks" \
     tests/spark_readiness_findings.adb >"$output" 2>&1
then
   echo "expected spark_readiness_findings.adb to produce violations" >&2
   exit 1
fi

for rule in \
   Missing_Global_Contract \
   Global_Contract_Mismatch \
   Missing_Depends_Contract \
   Incomplete_Depends_Contract \
   Uninitialized_Output
do
   if ! grep -F "[$rule]" "$output" >/dev/null; then
      echo "missing expected SPARK readiness finding: $rule" >&2
      cat "$output" >&2
      exit 1
   fi
done

if "$analyzer" --spark tests/spark_readiness_findings.adb \
     >"$output" 2>&1
then
   echo "the SPARK readiness preset unexpectedly found no violations" >&2
   exit 1
fi

for rule in \
   Missing_Global_Contract \
   Global_Contract_Mismatch \
   Missing_Depends_Contract \
   Incomplete_Depends_Contract \
   Uninitialized_Output
do
   if ! grep -F "[$rule]" "$output" >/dev/null; then
      echo "the --spark preset is missing readiness check $rule" >&2
      cat "$output" >&2
      exit 1
   fi
done

if ! "$analyzer" -q -checks="$spark_readiness_checks" \
     tests/spark_readiness_clean.adb
then
   echo "spark_readiness_clean.adb unexpectedly produced a violation" >&2
   "$analyzer" -checks="$spark_readiness_checks" \
      tests/spark_readiness_clean.adb >&2 || true
   exit 1
fi

if ! "$analyzer" -q --spark tests/spark_readiness_clean.adb; then
   echo "the clean SPARK readiness fixture fails the full preset" >&2
   "$analyzer" --spark tests/spark_readiness_clean.adb >&2 || true
   exit 1
fi

if "$analyzer" -checks='Depends_Contract_Mismatch' \
     tests/spark_dependency_findings.adb >"$output" 2>&1
then
   echo "expected spark_dependency_findings.adb to produce violations" >&2
   exit 1
fi

if ! grep -F '[Depends_Contract_Mismatch]' "$output" >/dev/null; then
   echo "missing inferred Depends mismatch findings" >&2
   cat "$output" >&2
   exit 1
fi

for text in \
   "may depend on input 'B'" \
   "no such flow is inferred" \
   "may depend on input 'Flag'" \
   "may depend on input 'X'" \
   "input 'B' is missing from the Depends relation" \
   "may depend on input 'A'" \
   "may depend on input 'N'"
do
   if ! grep -F "$text" "$output" >/dev/null; then
      echo "missing expected dependency diagnostic: $text" >&2
      cat "$output" >&2
      exit 1
   fi
done

if ! grep -F "depends on Proof_In global 'Proof'" "$output" >/dev/null; then
   echo "missing Proof_In dependency diagnostic" >&2
   cat "$output" >&2
   exit 1
fi

if ! "$analyzer" -q -checks='Depends_Contract_Mismatch' \
     tests/spark_dependency_clean.adb
then
   echo "spark_dependency_clean.adb unexpectedly produced a violation" >&2
   "$analyzer" -checks='Depends_Contract_Mismatch' \
      tests/spark_dependency_clean.adb >&2 || true
   exit 1
fi

if ! "$analyzer" -q -checks='Depends_Contract_Mismatch' \
     tests/spark_dependency_separate_clean.ads \
     tests/spark_dependency_separate_clean.adb
then
   echo "separate spec/body Depends mapping produced a false positive" >&2
   "$analyzer" -checks='Depends_Contract_Mismatch' \
      tests/spark_dependency_separate_clean.ads \
      tests/spark_dependency_separate_clean.adb >&2 || true
   exit 1
fi

if "$analyzer" -checks='Depends_Contract_Mismatch' \
     tests/spark_dependency_separate_findings.ads \
     tests/spark_dependency_separate_findings.adb >"$output" 2>&1
then
   echo "separate spec/body dependency mismatch was not detected" >&2
   exit 1
fi

if ! grep -F "may depend on input 'A'" "$output" >/dev/null; then
   echo "missing separate spec/body dependency diagnostic" >&2
   cat "$output" >&2
   exit 1
fi

if "$analyzer" --spark tests/spark_dependency_findings.adb \
     >"$output" 2>&1
then
   echo "the SPARK preset unexpectedly missed dependency mismatches" >&2
   exit 1
fi

if ! grep -F '[Depends_Contract_Mismatch]' "$output" >/dev/null; then
   echo "the --spark preset is missing Depends_Contract_Mismatch" >&2
   cat "$output" >&2
   exit 1
fi

echo "bug-finding regression tests passed"
