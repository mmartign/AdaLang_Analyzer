#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
clean=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-clean.XXXXXX")
loop=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-loop.XXXXXX")
unsupported=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-unsupported.XXXXXX")
call=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-call.XXXXXX")
many=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-many.XXXXXX")
initialization=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-init.XXXXXX")
initialization_defaults=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-init-defaults.XXXXXX")
initialization_rename=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-init-rename.XXXXXX")
initialization_pragma_unreferenced=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-init-pragma-unref.XXXXXX")
exception_model=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-exception.XXXXXX")
vc_clean=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-clean.XXXXXX")
vc_error=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-error.XXXXXX")
vc_unsupported=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-unsupported.XXXXXX")
vc_unavailable=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-unavailable.XXXXXX")
vc_guarded=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-guarded.XXXXXX")
vc_contracts=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-contracts.XXXXXX")
vc_division=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-division.XXXXXX")
vc_division_refuted=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-division-refuted.XXXXXX")
vc_division_zero_possible=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-division-zero.XXXXXX")
vc_call_inlined=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-call-inlined.XXXXXX")
vc_unsupported_provenance=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-provenance.XXXXXX")
vc_contract_loop_provenance=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-contract-loop-provenance.XXXXXX")
vc_runtime_solver=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-runtime-solver.XXXXXX")
vc_call_statement_body=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-call-stmt.XXXXXX")
vc_conversion=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-conversion.XXXXXX")
vc_conversion_modular=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-conversion-mod.XXXXXX")
vc_quantified=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-quantified.XXXXXX")
vc_quantified_outside=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-quantified-outside.XXXXXX")
vc_enum_assignment=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-enum-assignment.XXXXXX")
vc_enum_error=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-enum-error.XXXXXX")
vc_unsupported_sort=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-unsupported-sort.XXXXXX")
vc_derived_overflow_base=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-vc-derived-overflow-base.XXXXXX")
symbolic_assignment=$(mktemp "${TMPDIR:-/tmp}/adalang-symbolic-assignment.XXXXXX")
symbolic_branch=$(mktemp "${TMPDIR:-/tmp}/adalang-symbolic-branch.XXXXXX")
symbolic_join=$(mktemp "${TMPDIR:-/tmp}/adalang-symbolic-join.XXXXXX")
symbolic_call=$(mktemp "${TMPDIR:-/tmp}/adalang-symbolic-call.XXXXXX")
symbolic_prepost=$(mktemp "${TMPDIR:-/tmp}/adalang-symbolic-prepost.XXXXXX")
symbolic_loop=$(mktemp "${TMPDIR:-/tmp}/adalang-symbolic-loop.XXXXXX")
loop_vc_relational=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-vc-relational.XXXXXX")
loop_vc_broken=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-vc-broken.XXXXXX")
loop_branch_clean=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-clean.XXXXXX")
loop_branch_broken=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-broken.XXXXXX")
loop_branch_elsif_clean=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-elsif-clean.XXXXXX")
loop_branch_elsif_broken=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-elsif-broken.XXXXXX")
loop_branch_nested_if=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-nested-if.XXXXXX")
loop_branch_elsif_nested_if=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-elsif-nested-if.XXXXXX")
loop_branch_sequential_clean=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-sequential-clean.XXXXXX")
loop_branch_sequential_broken=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-sequential-broken.XXXXXX")
loop_branch_third_conditional=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-third-conditional.XXXXXX")
loop_branch_case_clean=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-case-clean.XXXXXX")
loop_branch_case_broken=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-case-broken.XXXXXX")
loop_branch_case_multi_choice=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-case-multi-choice.XXXXXX")
loop_branch_case_no_others=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-case-no-others.XXXXXX")
loop_branch_case_nested_if=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-case-nested-if.XXXXXX")
loop_branch_ite_precision=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-ite-precision.XXXXXX")
loop_branch_ite_unsafe=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-ite-unsafe.XXXXXX")
loop_branch_ite_cond_unsupported=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-ite-cond-unsupported.XXXXXX")
loop_branch_ite_cond_unsupported_precision=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-ite-cond-unsupported-precision.XXXXXX")
loop_branch_ite_cond_unsupported_unsafe=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-ite-cond-unsupported-unsafe.XXXXXX")
loop_invariant_independent_failure=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-invariant-independent-failure.XXXXXX")
loop_array_write=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-array-write.XXXXXX")
loop_record_write=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-record-write.XXXXXX")
loop_length_symbolic=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-length-symbolic.XXXXXX")
length_attribute_unsound=$(mktemp "${TMPDIR:-/tmp}/adalang-length-attribute-unsound.XXXXXX")
loop_variant_dynamic_bound=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-variant-dynamic-bound.XXXXXX")
loop_variant_increases=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-variant-increases.XXXXXX")
loop_variant_succ=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-variant-succ.XXXXXX")
loop_variant_wrong=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-variant-wrong.XXXXXX")
loop_variant_unsupported=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-variant-unsupported.XXXXXX")
loop_variant_leading_order=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-variant-leading-order.XXXXXX")
slice_index_conservative=$(mktemp "${TMPDIR:-/tmp}/adalang-slice-index-conservative.XXXXXX")
assert_false_guarded=$(mktemp "${TMPDIR:-/tmp}/adalang-assert-false-guarded.XXXXXX")
out_forwarding=$(mktemp "${TMPDIR:-/tmp}/adalang-out-forwarding.XXXXXX")
interprocedural_effects=$(mktemp "${TMPDIR:-/tmp}/adalang-interprocedural-effects.XXXXXX")
interprocedural_ordinary=$(mktemp "${TMPDIR:-/tmp}/adalang-interprocedural-ordinary.XXXXXX")
loop_stale_init=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-stale-init.XXXXXX")
loop_stale_range=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-stale-range.XXXXXX")
loop_stale_range_obligation=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-stale-range-ob.XXXXXX")
loop_stale_index=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-stale-index.XXXXXX")
loop_stale_division=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-stale-division.XXXXXX")
loop_stale_overflow=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-stale-overflow.XXXXXX")
loop_stale_assert=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-stale-assert.XXXXXX")
loop_stale_precondition=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-stale-precondition.XXXXXX")
global_aspect_clean=$(mktemp "${TMPDIR:-/tmp}/adalang-global-aspect-clean.XXXXXX")
deferred=$(mktemp "${TMPDIR:-/tmp}/adalang-deferred.XXXXXX")
termination=$(mktemp "${TMPDIR:-/tmp}/adalang-termination.XXXXXX")
flow_contracts=$(mktemp "${TMPDIR:-/tmp}/adalang-flow-contracts.XXXXXX")
expression_functions=$(mktemp "${TMPDIR:-/tmp}/adalang-expression-functions.XXXXXX")
function_terms=$(mktemp "${TMPDIR:-/tmp}/adalang-function-terms.XXXXXX")
call_frame=$(mktemp "${TMPDIR:-/tmp}/adalang-call-frame.XXXXXX")
fp110=$(mktemp "${TMPDIR:-/tmp}/adalang-fp110.XXXXXX")
call_postcondition=$(mktemp "${TMPDIR:-/tmp}/adalang-call-postcondition.XXXXXX")
fp112=$(mktemp "${TMPDIR:-/tmp}/adalang-fp112.XXXXXX")
fp113=$(mktemp "${TMPDIR:-/tmp}/adalang-fp113.XXXXXX")
quantified_invariant=$(mktemp "${TMPDIR:-/tmp}/adalang-quantified-invariant.XXXXXX")
named_values=$(mktemp "${TMPDIR:-/tmp}/adalang-named-values.XXXXXX")
forward_goto=$(mktemp "${TMPDIR:-/tmp}/adalang-forward-goto.XXXXXX")
named_loops=$(mktemp "${TMPDIR:-/tmp}/adalang-named-loops.XXXXXX")
type_size=$(mktemp "${TMPDIR:-/tmp}/adalang-type-size.XXXXXX")
provisional_error=$(mktemp "${TMPDIR:-/tmp}/adalang-provisional-error.XXXXXX")
fp115=$(mktemp "${TMPDIR:-/tmp}/adalang-fp115.XXXXXX")
fp116=$(mktemp "${TMPDIR:-/tmp}/adalang-fp116.XXXXXX")
length_conversion=$(mktemp "${TMPDIR:-/tmp}/adalang-length-conversion.XXXXXX")
length_limits=$(mktemp "${TMPDIR:-/tmp}/adalang-length-limits.XXXXXX")
length_check=$(mktemp "${TMPDIR:-/tmp}/adalang-length-check.XXXXXX")
length_check_state=$(mktemp "${TMPDIR:-/tmp}/adalang-length-check-state.XXXXXX")
standing_values=$(mktemp "${TMPDIR:-/tmp}/adalang-standing-values.XXXXXX")
termination_iteration=$(mktemp "${TMPDIR:-/tmp}/adalang-termination-iteration.XXXXXX")
global_aspect_guard=$(mktemp "${TMPDIR:-/tmp}/adalang-global-aspect-guard.XXXXXX")
aborted_fixpoint=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-aborted-fixpoint.XXXXXX")
fp086=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp086.XXXXXX")
fp087=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp087.XXXXXX")
fp088=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp088.XXXXXX")
fp089=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp089.XXXXXX")
membership=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-membership.XXXXXX")
own_range=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-own-range.XXXXXX")
fp090=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp090.XXXXXX")
fp091=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp091.XXXXXX")
fp092=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp092.XXXXXX")
fp093=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp093.XXXXXX")
fp094=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp094.XXXXXX")
converged=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-converged.XXXXXX")
completion=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-completion.XXXXXX")
spark_project=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-spark-project.XXXXXX")
spark_bare=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-spark-bare.XXXXXX")
fp097=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp097.XXXXXX")
fp098=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp098.XXXXXX")
fp099=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp099.XXXXXX")
fp100=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp100.XXXXXX")
symbolic_bounds=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-symbolic-bounds.XXXXXX")
symbolic_dimensions=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-symbolic-dimensions.XXXXXX")
fp101=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-fp101.XXXXXX")
initializer_bounds=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-initializer-bounds.XXXXXX")
pre_globals=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-pre-globals.XXXXXX")
own_name_qualifier=$(mktemp "${TMPDIR:-/tmp}/adalang-own-name-qualifier.XXXXXX")
cross_project=$(mktemp "${TMPDIR:-/tmp}/adalang-cross-project.XXXXXX")
cross_project_stderr=$(mktemp "${TMPDIR:-/tmp}/adalang-cross-project-stderr.XXXXXX")
trap 'rm -f "$clean" "$loop" "$unsupported" "$call" "$many" "$initialization" "$initialization_defaults" "$initialization_rename" "$exception_model" "$vc_clean" "$vc_error" "$vc_unsupported" "$vc_unavailable" "$vc_guarded" "$vc_contracts" "$vc_division" "$vc_division_refuted" "$vc_division_zero_possible" "$vc_call_inlined" "$vc_unsupported_provenance" "$vc_contract_loop_provenance" "$vc_runtime_solver" "$vc_call_statement_body" "$vc_conversion" "$vc_conversion_modular" "$vc_quantified" "$vc_quantified_outside" "$vc_enum_assignment" "$vc_enum_error" "$vc_unsupported_sort" "$vc_derived_overflow_base" "$symbolic_assignment" "$symbolic_branch" "$symbolic_join" "$symbolic_call" "$symbolic_prepost" "$symbolic_loop" "$loop_vc_relational" "$loop_vc_broken" "$loop_branch_clean" "$loop_branch_broken" "$loop_branch_elsif_clean" "$loop_branch_elsif_broken" "$loop_branch_nested_if" "$loop_branch_elsif_nested_if" "$loop_branch_sequential_clean" "$loop_branch_sequential_broken" "$loop_branch_third_conditional" "$loop_branch_case_clean" "$loop_branch_case_broken" "$loop_branch_case_multi_choice" "$loop_branch_case_no_others" "$loop_branch_case_nested_if" "$loop_branch_ite_precision" "$loop_branch_ite_unsafe" "$loop_branch_ite_cond_unsupported" "$loop_branch_ite_cond_unsupported_precision" "$loop_branch_ite_cond_unsupported_unsafe" "$loop_invariant_independent_failure" "$loop_array_write" "$loop_record_write" "$loop_length_symbolic" "$length_attribute_unsound" "$loop_variant_dynamic_bound" "$loop_variant_increases" "$loop_variant_succ" "$loop_variant_wrong" "$loop_variant_unsupported" "$loop_variant_leading_order" "$slice_index_conservative" "$assert_false_guarded" "$out_forwarding" "$interprocedural_effects" "$interprocedural_ordinary" "$loop_stale_init" "$loop_stale_range" "$loop_stale_range_obligation" "$loop_stale_index" "$loop_stale_division" "$loop_stale_overflow" "$loop_stale_assert" "$loop_stale_precondition" "$global_aspect_clean" "$global_aspect_guard" "$initialization_pragma_unreferenced" "$own_name_qualifier" "$aborted_fixpoint" "$fp086" "$fp087" "$fp088" "$fp089" "$membership" "$own_range" "$fp090" "$fp091" "$fp092" "$fp093" "$fp094" "$converged" "$completion" "$spark_project" "$spark_bare" "$fp097" "$fp098" "$fp099" "$fp100" "$symbolic_bounds" "$symbolic_dimensions" "$fp101" "$initializer_bounds" "$pre_globals" "$deferred" "$termination" "$termination_iteration" "$flow_contracts" "$expression_functions" "$function_terms" "$call_frame" "$fp110" "$call_postcondition" "$fp112" "$fp113" "$quantified_invariant" "$named_values" "$forward_goto" "$named_loops" "$type_size" "$provisional_error" "$fp115" "$fp116" "$length_conversion" "$length_limits" "$length_check" "$length_check_state" "$standing_values"' EXIT HUP INT TERM

run_json()
{
   output=$1
   source=$2
   status=0
   "$analyzer" --verify -q --format=json --output="$output" "$source" ||
     status=$?
   if [ "$status" -gt 1 ]; then
      echo "verification run failed for $source with status $status" >&2
      exit "$status"
   fi
}

run_json "$clean" tests/verification_clean.adb
grep -F '"provedSafe":' "$clean" >/dev/null
grep -F '"status": "proved-safe"' "$clean" >/dev/null
grep -F '"status": "unreachable"' "$clean" >/dev/null
grep -F '"kind": "postcondition", "status": "proved-safe"' "$clean" >/dev/null

run_json "$loop" tests/verification_loop_clean.adb
grep -F '"kind": "assertion", "status": "proved-safe"' "$loop" >/dev/null
grep -F '"kind": "loop-invariant-initialization"' "$loop" >/dev/null
grep -F '"kind": "loop-invariant-preservation"' "$loop" >/dev/null
grep -F '"kind": "loop-variant", "status": "proved-safe", "method": "external-prover"' \
  "$loop" >/dev/null

run_json "$call" tests/verification_call_clean.adb
grep -F '"kind": "assertion", "status": "proved-safe"' "$call" >/dev/null

run_json "$out_forwarding" tests/verification_diff_modular_call.adb
if grep -F '"kind": "initialization-check", "status": "definite-error"' \
  "$out_forwarding" >/dev/null; then
   echo "out-to-out forwarding was classified as an uninitialized read" >&2
   exit 1
fi

run_json "$interprocedural_effects" \
  tests/interprocedural_effect_summaries.adb
grep -F '"kind": "assertion", "status": "proved-safe"' \
  "$interprocedural_effects" | grep -F '"operation": "Denominator = 0"' \
  >/dev/null
grep -F '"kind": "initialization-check", "status": "proved-safe"' \
  "$interprocedural_effects" | grep -F '"operation": "Result"' >/dev/null
grep -F '"kind": "initialization-check", "status": "unproved"' \
  "$interprocedural_effects" | grep -F '"operation": "Maybe_Result"' \
  >/dev/null
grep -F '"kind": "initialization-check", "status": "definite-error"' \
  "$interprocedural_effects" | grep -F '"operation": "Shadow_Result"' \
  >/dev/null
grep -F '"kind": "assertion", "status": "unproved"' \
  "$interprocedural_effects" | grep -F '"operation": "Changed = 1"' \
  >/dev/null
if grep -F '"kind": "assertion", "status": "proved-safe"' \
  "$interprocedural_effects" | grep -F '"operation": "Changed = 1"' \
  >/dev/null; then
   echo "transitive nonlocal write left stale state in verification" >&2
   exit 1
fi

ordinary_status=0
"$analyzer" -checks=Division_By_Zero \
  tests/interprocedural_effect_summaries.adb >"$interprocedural_ordinary" 2>&1 \
  || ordinary_status=$?
if [ "$ordinary_status" -ne 1 ] \
  || [ "$(grep -c '\[Division_By_Zero\]' "$interprocedural_ordinary")" -ne 1 ]
then
   echo "ordinary flow did not retain an unaffected fact across a known call" \
     >&2
   cat "$interprocedural_ordinary" >&2
   exit 1
fi
if grep -F '"line": 23, "column": 20, "operation": "Result"' \
  "$out_forwarding" >/dev/null; then
   echo "out-to-out forwarding emitted a read obligation for the destination" >&2
   exit 1
fi

run_json "$many" tests/verification_many_variables.adb
grep -F '"kind": "assertion", "status": "proved-safe"' "$many" >/dev/null

run_json "$initialization" tests/verification_initialization_error.adb
grep -F '"kind": "initialization-check", "status": "definite-error"' \
  "$initialization" >/dev/null

run_json "$initialization_defaults" \
  tests/verification_initialization_defaults_clean.adb
if grep -F '"kind": "initialization-check", "status": "definite-error"' \
  "$initialization_defaults" >/dev/null; then
   echo "default-initialized or renamed object was classified as definitely uninitialized" >&2
   exit 1
fi
grep -F '"kind": "initialization-check", "status": "proved-safe"' \
  "$initialization_defaults" | grep -F '"operation": "Copy"' >/dev/null
grep -F '"kind": "initialization-check", "status": "unproved"' \
  "$initialization_defaults" | grep -F '"operation": "Item"' >/dev/null
grep -F '"kind": "initialization-check", "status": "unproved"' \
  "$initialization_defaults" | grep -F '"operation": "Data"' >/dev/null
grep -F '"kind": "initialization-check", "status": "unproved"' \
  "$initialization_defaults" | grep -F '"operation": "Overlay"' >/dev/null

run_json "$initialization_rename" \
  tests/verification_initialization_rename_error.adb
grep -F '"kind": "initialization-check", "status": "definite-error"' \
  "$initialization_rename" >/dev/null

run_json "$initialization_pragma_unreferenced" \
  tests/verification_initialization_pragma_unreferenced_clean.adb
if grep -F '"kind": "initialization-check", "status": "definite-error"' \
  "$initialization_pragma_unreferenced" >/dev/null; then
   echo "pragma Unreferenced argument was classified as a definite read" >&2
   exit 1
fi

run_json "$exception_model" tests/verification_exception_model.adb
grep -F '"kind": "division-by-zero", "status": "unproved"' \
  "$exception_model" >/dev/null
if grep -F '"kind": "division-by-zero", "status": "proved-safe"' \
  "$exception_model" >/dev/null; then
   echo "exceptional call effects left a stale proved-safe fact" >&2
   exit 1
fi

run_json "$vc_clean" tests/verification_vc_clean.adb
grep -F '"kind": "assertion", "status": "proved-safe", "method": "external-prover"' \
  "$vc_clean" >/dev/null
grep -F 'CVC5 and Z3 agreement required' "$vc_clean" >/dev/null

run_json "$vc_error" tests/verification_vc_error.adb
grep -F '"kind": "assertion", "status": "definite-error", "method": "external-prover"' \
  "$vc_error" >/dev/null

run_json "$vc_unsupported" tests/verification_vc_unsupported.adb
grep -F '"kind": "assertion", "status": "unproved"' \
  "$vc_unsupported" >/dev/null

run_json "$vc_guarded" tests/verification_vc_guarded_refutation.adb
grep -F '"kind": "assertion", "status": "unproved"' "$vc_guarded" >/dev/null
if grep -F '"kind": "assertion", "status": "definite-error"' \
  "$vc_guarded" >/dev/null; then
   echo "partial arithmetic expression was reported as a definite assertion" >&2
   exit 1
fi

run_json "$vc_contracts" tests/verification_vc_contracts.adb
grep -F '"kind": "precondition", "status": "proved-safe", "method": "external-prover"' \
  "$vc_contracts" >/dev/null
grep -F '"kind": "postcondition", "status": "proved-safe", "method": "external-prover"' \
  "$vc_contracts" >/dev/null

run_json "$vc_division" tests/verification_vc_division.adb
grep -F '"operation": "X mod Y >= 0"' "$vc_division" |
  grep -F '"status": "proved-safe", "method": "external-prover"' >/dev/null
grep -F '"operation": "X mod Y < Y"' "$vc_division" |
  grep -F '"status": "proved-safe", "method": "external-prover"' >/dev/null
grep -F '"operation": "X rem Y >= 0"' "$vc_division" |
  grep -F '"status": "proved-safe", "method": "external-prover"' >/dev/null

run_json "$vc_division_refuted" tests/verification_vc_division_refuted.adb
grep -F '"kind": "assertion", "status": "definite-error", "method": "external-prover"' \
  "$vc_division_refuted" >/dev/null

#  FP-065: "pragma Assert (False)" under a conditional whose guard the
#  analysis cannot prove taken is not a *definite* failure -- it must be
#  unproved, never definite-error (a straight-line one still fires, see
#  verification_vc_error.adb above). Found on AdaCore SPARK testsuite unit
#  W316-007__string_multidim via benchmarks/spark_testsuite/.
run_json "$assert_false_guarded" tests/verification_assert_false_guarded.adb
grep -F '"kind": "assertion", "status": "unproved"' \
  "$assert_false_guarded" | grep -F '"operation": "False"' >/dev/null
if grep -F '"kind": "assertion", "status": "definite-error"' \
  "$assert_false_guarded" >/dev/null; then
   echo "a conditionally-guarded pragma Assert (False) whose guard could" \
     "not be evaluated was reported as a definite failure (FP-065)" >&2
   exit 1
fi

run_json "$vc_division_zero_possible" \
  tests/verification_vc_division_zero_possible.adb
grep -F '"kind": "assertion", "status": "unproved"' \
  "$vc_division_zero_possible" |
  grep -F '"reasonCode": "unsafe-divisor-semantics"' |
  grep -F '"blockingExpression": "X mod Y"' >/dev/null
if grep -F '"kind": "assertion", "status": "proved-safe"' \
  "$vc_division_zero_possible" >/dev/null; then
   echo "a divisor range spanning zero was treated as provably nonzero" >&2
   exit 1
fi

run_json "$vc_call_inlined" tests/verification_vc_call_inlined.adb
grep -F '"kind": "assertion", "status": "proved-safe", "method": "external-prover"' \
  "$vc_call_inlined" >/dev/null
if [ "$(grep -F -c '"kind": "assertion", "status": "proved-safe", "method": "external-prover"' \
  "$vc_call_inlined")" -ne 2 ]; then
   echo "an inlined record formal did not preserve the actual object's identity" >&2
   exit 1
fi

run_json "$vc_unsupported_provenance" \
  tests/verification_vc_unsupported_provenance.adb
grep -F '"operation": "X ** 2 >= 0"' "$vc_unsupported_provenance" |
  grep -F '"reasonCode": "unsupported-operator"' |
  grep -F '"blockingExpression": "X ** 2"' |
  grep -F '"inlinePath": ""' >/dev/null
grep -F '"operation": "Square (X) >= 0"' "$vc_unsupported_provenance" |
  grep -F '"reasonCode": "unsupported-operator"' |
  grep -F '"blockingExpression": "Value ** 2"' |
  grep -F '"inlinePath": "Square"' >/dev/null
grep -F '"operation": "Outer (X) >= 0"' "$vc_unsupported_provenance" |
  grep -F '"reasonCode": "unsupported-operator"' |
  grep -F '"blockingExpression": "Value ** 2"' |
  grep -F '"inlinePath": "Outer -> Square"' >/dev/null

run_json "$vc_contract_loop_provenance" \
  tests/verification_vc_contract_loop_provenance.adb
for kind in precondition postcondition loop-invariant-initialization \
  loop-invariant-preservation
do
  grep -F "\"kind\": \"$kind\"" "$vc_contract_loop_provenance" |
    grep -F '"reasonCode": "unsupported-operator"' |
    grep -F '"blockingExpression": "' >/dev/null
done

run_json "$vc_runtime_solver" tests/verification_vc_runtime_solver.adb
grep -F '"kind": "range-check", "status": "proved-safe", "method": "external-prover"' \
  "$vc_runtime_solver" | grep -F '"operation": "X - Y"' >/dev/null
grep -F '"kind": "index-check", "status": "proved-safe", "method": "external-prover"' \
  "$vc_runtime_solver" | grep -F '"operation": "X - Y + 10"' >/dev/null
grep -F '"kind": "division-by-zero", "status": "proved-safe", "method": "external-prover"' \
  "$vc_runtime_solver" | grep -F '"operation": "(Y - X)"' >/dev/null
grep -F '"kind": "integer-overflow", "status": "proved-safe", "method": "external-prover"' \
  "$vc_runtime_solver" | grep -F '"operation": "X - Y"' >/dev/null
grep -F '"kind": "range-check", "status": "definite-error", "method": "external-prover"' \
  "$vc_runtime_solver" | grep -F '"operation": "Y - X"' >/dev/null
grep -F '"kind": "range-check", "status": "unproved"' "$vc_runtime_solver" |
  grep -F '"operation": "X ** 2"' |
  grep -F '"reasonCode": "unsupported-operator"' |
  grep -F '"blockingExpression": "X ** 2"' >/dev/null

run_json "$vc_call_statement_body" tests/verification_vc_call_statement_body.adb
grep -F '"kind": "assertion", "status": "unproved"' \
  "$vc_call_statement_body" |
  grep -F '"reasonCode": "callee-not-expression-function"' |
  grep -F '"blockingExpression": "Double (X)"' |
  grep -F '"inlinePath": "Double"' >/dev/null
if grep -F '"kind": "assertion", "status": "proved-safe"' \
  "$vc_call_statement_body" >/dev/null; then
   echo "a statement-bodied function call was inlined like an expression function" >&2
   exit 1
fi

run_json "$vc_conversion" tests/verification_vc_conversion.adb
grep -F '"kind": "assertion", "status": "proved-safe", "method": "external-prover"' \
  "$vc_conversion" >/dev/null

run_json "$vc_conversion_modular" tests/verification_vc_conversion_modular.adb
grep -F '"kind": "assertion", "status": "unproved"' \
  "$vc_conversion_modular" |
  grep -F '"reasonCode": "unsupported-conversion"' |
  grep -F '"blockingExpression": "Byte (X)"' >/dev/null
grep -F '"kind": "range-check", "status": "unproved"' \
  "$vc_conversion_modular" |
  grep -F '"reasonCode": "unsupported-conversion"' |
  grep -F '"blockingExpression": "Byte (X)"' >/dev/null
if grep -F '"kind": "assertion", "status": "proved-safe"' \
  "$vc_conversion_modular" >/dev/null; then
   echo "a modular type conversion was translated as an identity" >&2
   exit 1
fi

run_json "$vc_quantified" tests/verification_vc_quantified.adb
grep -F '"operation": "for all I in 1 .. 10 => I >= 1"' "$vc_quantified" |
  grep -F '"status": "proved-safe", "method": "external-prover"' >/dev/null
grep -F '"operation": "for some I in 1 .. 10 => I = 7"' "$vc_quantified" |
  grep -F '"status": "proved-safe", "method": "external-prover"' >/dev/null

run_json "$vc_quantified_outside" \
  tests/verification_vc_quantified_outside_assertion.adb
grep -F '"kind": "assertion", "status": "unsupported"' \
  "$vc_quantified_outside" >/dev/null
if grep -F '"kind": "assertion", "status": "proved-safe"' \
  "$vc_quantified_outside" >/dev/null; then
   echo "a quantified expression outside Pre/Post/Assert widened the Contains_Unsupported_Semantics carve-out" >&2
   exit 1
fi

run_json "$vc_enum_assignment" tests/verification_vc_enum_assignment.adb
for operation in \
  'Input = Admin' \
  'Current = Admin' \
  'Current in Guest | Admin' \
  'Truth /= True'
do
   grep -F "\"operation\": \"$operation\"" "$vc_enum_assignment" |
     grep -F '"status": "proved-safe", "method": "external-prover"' \
       >/dev/null
done

run_json "$vc_enum_error" tests/verification_vc_enum_assignment_error.adb
grep -F '"operation": "Truth = True"' "$vc_enum_error" |
  grep -F '"status": "definite-error", "method": "external-prover"' \
    >/dev/null

run_json "$vc_unsupported_sort" \
  tests/verification_vc_unsupported_scalar_sort.adb
grep -F '"operation": "Copy = Input"' "$vc_unsupported_sort" |
  grep -F '"status": "unproved"' |
  grep -F '"reasonCode": "sort-mismatch"' |
  grep -F '"blockingExpression": "Copy"' >/dev/null
if grep -F '"kind": "assertion", "status": "proved-safe"' \
  "$vc_unsupported_sort" >/dev/null; then
   echo "an unsupported fixed-point scalar sort entered the SMT proof path" >&2
   exit 1
fi

#  RFLX_Types.Index/Length shape (coap_spark): a twice-derived type ("new
#  Length range 1 .. Length'Last", itself "new Natural") whose visible
#  first-subtype constraint is narrower than its true machine base range.
#  "X - 2" (X = Index'First = 1) is -1: outside Index's and Length's own
#  declared constraints, but comfortably inside the true base range every
#  derivation ultimately inherits from Integer. Only a single P_Base_Type
#  hop reaches Length's still-narrow constraint; the overflow check must
#  walk to the derivation root to avoid a false Definite_Error here.
run_json "$vc_derived_overflow_base" \
  tests/verification_vc_derived_overflow_base.adb
grep -F '"operation": "X - 2"' "$vc_derived_overflow_base" |
  grep -F '"kind": "integer-overflow", "status": "proved-safe"' >/dev/null
if grep -F '"status": "definite-error"' "$vc_derived_overflow_base" >/dev/null; then
   echo "a twice-derived type's narrow first-subtype constraint produced a false Definite_Error" >&2
   exit 1
fi

run_json "$symbolic_assignment" tests/verification_symbolic_assignment.adb
grep -F '"kind": "assertion", "status": "proved-safe", "method": "external-prover"' \
  "$symbolic_assignment" >/dev/null
grep -F '"kind": "precondition", "status": "proved-safe", "method": "external-prover"' \
  "$symbolic_assignment" >/dev/null

run_json "$symbolic_branch" tests/verification_symbolic_branch.adb
grep -F '"kind": "assertion", "status": "proved-safe", "method": "external-prover"' \
  "$symbolic_branch" >/dev/null

run_json "$symbolic_join" tests/verification_symbolic_join.adb
grep -F '"operation": "Y = X + 1"' "$symbolic_join" |
  grep -F '"status": "unproved"' >/dev/null
grep -F '"operation": "Z = X + 3"' "$symbolic_join" |
  grep -F '"status": "proved-safe", "method": "external-prover"' >/dev/null

run_json "$symbolic_call" tests/verification_symbolic_call.adb
grep -F '"kind": "assertion", "status": "unproved"' "$symbolic_call" >/dev/null
if grep -F '"kind": "assertion", "status": "proved-safe"' \
  "$symbolic_call" >/dev/null; then
   echo "symbolic fact survived a call without a relational postcondition" >&2
   exit 1
fi

run_json "$symbolic_prepost" tests/verification_symbolic_prepost.adb
grep -F '"kind": "postcondition", "status": "proved-safe", "method": "external-prover"' \
  "$symbolic_prepost" >/dev/null

run_json "$symbolic_loop" tests/verification_symbolic_loop.adb
grep -F '"kind": "assertion", "status": "unproved"' "$symbolic_loop" >/dev/null
if grep -F '"kind": "assertion", "status": "proved-safe"' \
  "$symbolic_loop" >/dev/null; then
   echo "symbolic loop facts bypassed the widening cutoff" >&2
   exit 1
fi

run_json "$loop_vc_relational" tests/verification_loop_vc_relational.adb
grep -F '"kind": "loop-invariant-initialization", "status": "proved-safe"' \
  "$loop_vc_relational" >/dev/null
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_vc_relational" >/dev/null
grep -F '"kind": "postcondition", "status": "proved-safe"' \
  "$loop_vc_relational" >/dev/null

run_json "$loop_vc_broken" tests/verification_loop_vc_broken.adb
grep -F '"kind": "loop-invariant-initialization", "status": "proved-safe"' \
  "$loop_vc_broken" >/dev/null
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_vc_broken" >/dev/null
grep -F '"kind": "postcondition", "status": "unproved"' \
  "$loop_vc_broken" >/dev/null
if grep -F '"kind": "postcondition", "status": "proved-safe"' \
  "$loop_vc_broken" >/dev/null; then
   echo "an unpreserved invariant escaped into the postcondition proof" >&2
   exit 1
fi

#  A loop body containing exactly one non-nested if/else, both arms
#  reconverging on the loop back edge, is a supported subset of loop
#  invariant preservation / variant progress (see the branch-merge design in
#  SUPPORTED_VERIFICATION_SUBSET.md). Extra is touched only inside the
#  branch and no obligation depends on it, so both arms' merged symbolic
#  state should still let the invariant/variant/postcondition discharge.
run_json "$loop_branch_clean" tests/verification_loop_branch_clean.adb
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_clean" >/dev/null
grep -F '"kind": "loop-variant", "status": "proved-safe", "method": "external-prover"' \
  "$loop_branch_clean" >/dev/null
grep -F '"kind": "postcondition", "status": "proved-safe"' \
  "$loop_branch_clean" >/dev/null

#  Same one-level if/else shape, but the invariant also constrains Extra,
#  and the two arms genuinely disagree on it (one increments, the other
#  decrements) -- a real defect, not just analyzer imprecision. The merged
#  symbolic state must stay conservative: preservation (and, as a knock-on
#  consequence of variant progress being gated on a discharged leading
#  invariant, the variant too) must never become proved-safe.
run_json "$loop_branch_broken" tests/verification_loop_branch_vc_broken.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_branch_broken" >/dev/null
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_branch_broken" >/dev/null
if grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_broken" >/dev/null; then
   echo "branches disagreeing on Extra escaped into a false loop-invariant proof" >&2
   exit 1
fi

#  An elsif/else chain folds into the same fork-and-join machinery as a
#  single if/else: each Condition_Node in the chain is its own binary
#  Join_On_Condition, right-folded into nested ite terms exactly matching
#  Ada's own elsif desugaring (see SUPPORTED_VERIFICATION_SUBSET.md).
#  Extra is untouched by the invariant, so every arm's merged symbolic
#  state still lets the invariant/variant/postcondition discharge.
run_json "$loop_branch_elsif_clean" \
  tests/verification_loop_branch_elsif_clean.adb
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_elsif_clean" >/dev/null
grep -F '"kind": "loop-variant", "status": "proved-safe", "method": "external-prover"' \
  "$loop_branch_elsif_clean" >/dev/null
grep -F '"kind": "postcondition", "status": "proved-safe"' \
  "$loop_branch_elsif_clean" >/dev/null

#  Same three-arm elsif shape, but the invariant also constrains Extra,
#  and the middle elsif arm genuinely disagrees with the other two -- a
#  real defect, not analyzer imprecision. The chained ite-join must stay
#  conservative: preservation (and, as a knock-on consequence of variant
#  progress being gated on a discharged leading invariant, the variant
#  too) must never become proved-safe.
run_json "$loop_branch_elsif_broken" \
  tests/verification_loop_branch_elsif_vc_broken.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_branch_elsif_broken" >/dev/null
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_branch_elsif_broken" >/dev/null
if grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_elsif_broken" >/dev/null; then
   echo "an elsif chain's disagreeing arms escaped into a false loop-invariant proof" >&2
   exit 1
fi

#  A lexically distinct, genuinely nested if inside an else arm -- as
#  opposed to that arm's own elsif/else continuation of the same
#  If_Stmt -- draws on the same Branch_Budget an equivalent sequential
#  conditional would (flow_interp.adb's Advance), so it is no longer
#  rejected on syntax alone; here it must still end up Unproved, but
#  because the outer condition (Flag) tells the solver nothing about the
#  inner one (X = 0), so the two arms' genuinely disagreeing effect on
#  Extra is a real, unrelated defect the budget increase must not paper
#  over. Guards the AST-ancestry check (Continues_Same_If_Chain in
#  flow_interp.adb) that distinguishes a chain continuation from a
#  lexically distinct nested If_Stmt: the nested if's disagreeing arms
#  are crafted so a misclassification would show up as a false proof,
#  not silent imprecision.
run_json "$loop_branch_nested_if" \
  tests/verification_loop_branch_nested_if_unsupported.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_branch_nested_if" >/dev/null
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_branch_nested_if" >/dev/null
if grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_nested_if" >/dev/null; then
   echo "a genuinely nested if escaped into a false loop-invariant proof" >&2
   exit 1
fi

#  Same shape, but the nested if lives inside an elsif arm's own body
#  rather than the trailing else -- exercises the true-arm side of the
#  fork, which now also carries forward the remaining Branch_Budget
#  (previously forced to 0 unconditionally). Unlike the sibling case
#  above, this one genuinely must prove: the elsif's own condition
#  (X = 1) already contradicts the nested if's condition (X = 2), so the
#  nested if's disagreeing arms are dead code on this path and the
#  invariant holds regardless -- the solver, not this test, establishes
#  that from the accumulated path facts. Renamed from
#  "..._unsupported" to "..._clean" once this stopped being an
#  unsupported shape.
run_json "$loop_branch_elsif_nested_if" \
  tests/verification_loop_branch_elsif_nested_if_clean.adb
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_elsif_nested_if" >/dev/null
grep -F '"kind": "loop-variant", "status": "proved-safe", "method": "external-prover"' \
  "$loop_branch_elsif_nested_if" >/dev/null

#  Two independent, sequential (not nested) if statements in the same
#  loop body -- the other shape Branch_Budget was added for. Both
#  agree on Extra regardless of Flag/X, so preservation must prove.
run_json "$loop_branch_sequential_clean" \
  tests/verification_loop_branch_sequential_clean.adb
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_sequential_clean" >/dev/null
grep -F '"kind": "loop-variant", "status": "proved-safe", "method": "external-prover"' \
  "$loop_branch_sequential_clean" >/dev/null

#  Same two-sequential-conditionals shape, but the second conditional's
#  arms genuinely disagree on Extra (X = 0 drives it negative) -- must
#  stay conservative rather than let the first (agreeing) conditional's
#  proof alone carry the whole preservation obligation.
run_json "$loop_branch_sequential_broken" \
  tests/verification_loop_branch_sequential_vc_broken.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_branch_sequential_broken" >/dev/null
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_branch_sequential_broken" >/dev/null
if grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_sequential_broken" >/dev/null; then
   echo "a disagreeing second sequential conditional escaped into a false loop-invariant proof" >&2
   exit 1
fi

#  Three independent sequential conditionals exceed Max_Branch_Depth (2):
#  the third one's genuinely disagreeing arms (X = 1 drives Extra
#  sharply negative) must not be silently ignored once the budget is
#  exhausted -- this must stay Unproved by hitting the budget wall, not
#  by accident.
run_json "$loop_branch_third_conditional" \
  tests/verification_loop_branch_third_conditional_unsupported.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_branch_third_conditional" >/dev/null
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_branch_third_conditional" >/dev/null
if grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_third_conditional" >/dev/null; then
   echo "a third independent conditional escaped Max_Branch_Depth into a false loop-invariant proof" >&2
   exit 1
fi
#  The budget wall is a documented subset boundary, so both obligations
#  carry it as unsupported provenance naming the blocking conditional.
for kind in loop-invariant-preservation loop-variant; do
   if ! grep -F "\"kind\": \"$kind\", \"status\": \"unproved\"" \
       "$loop_branch_third_conditional" |
     grep -F '"reasonCode": "branch-budget-exceeded"' |
     grep -F '"blockingExpression": "X = 1"' >/dev/null
   then
      echo "$kind past Max_Branch_Depth lacks branch-budget-exceeded provenance" >&2
      exit 1
   fi
done

#  A case statement folds the same way an elsif chain does: every
#  alternative but a trailing, explicit others is walked and joined via
#  VC.Join_On_Range, right-folded so the trailing others is the fold's
#  base case (needing no selector, mirroring elsif's own bare trailing
#  else). Extra is untouched by the invariant, so every alternative's
#  merged symbolic state still lets the invariant/variant/postcondition
#  discharge.
run_json "$loop_branch_case_clean" \
  tests/verification_loop_branch_case_clean.adb
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_case_clean" >/dev/null
grep -F '"kind": "loop-variant", "status": "proved-safe", "method": "external-prover"' \
  "$loop_branch_case_clean" >/dev/null
grep -F '"kind": "postcondition", "status": "proved-safe"' \
  "$loop_branch_case_clean" >/dev/null

#  Same case shape, but one alternative genuinely disagrees with the
#  others on Extra -- a real defect. The range-ite join must stay
#  conservative: preservation (and, as a knock-on consequence of variant
#  progress being gated on a discharged leading invariant, the variant
#  too) must never become proved-safe.
run_json "$loop_branch_case_broken" \
  tests/verification_loop_branch_case_vc_broken.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_branch_case_broken" >/dev/null
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_branch_case_broken" >/dev/null
if grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_case_broken" >/dev/null; then
   echo "a case alternative's disagreeing effect escaped into a false loop-invariant proof" >&2
   exit 1
fi

#  A multi-choice alternative ("when 0 | 2 =>") must be rejected outright,
#  never folded by widening its choices into one covering range -- that
#  would unsoundly admit selector values (1, here) that actually belong
#  to a different alternative. This guards the structural subset check
#  (every alternative but others must have exactly one choice) that
#  prevents Range_Union-style widening from ever being reached.
run_json "$loop_branch_case_multi_choice" \
  tests/verification_loop_branch_case_multi_choice_unsupported.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_branch_case_multi_choice" >/dev/null
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_branch_case_multi_choice" >/dev/null
if grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_case_multi_choice" >/dev/null; then
   echo "a multi-choice case alternative escaped into a false loop-invariant proof" >&2
   exit 1
fi

#  A case statement with no others (even one that is, by inspection,
#  exhaustive over its subtype) must also be rejected outright -- the
#  supported subset requires an explicit trailing others as the fold's
#  base case, and does not itself attempt to prove static exhaustiveness.
run_json "$loop_branch_case_no_others" \
  tests/verification_loop_branch_case_no_others_unsupported.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_branch_case_no_others" >/dev/null
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_branch_case_no_others" >/dev/null
if grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_case_no_others" >/dev/null; then
   echo "a case statement with no others escaped into a false loop-invariant proof" >&2
   exit 1
fi

#  A lexically nested if inside a case alternative's own body now draws
#  on the same remaining Branch_Budget an alternative's own body carries
#  forward (the case-statement counterpart of the elsif family's own
#  nested-if shape above), and here it genuinely must prove: the
#  alternative's own selector ("when 0 =>") already establishes Mode = 0,
#  contradicting the nested if's condition (Mode = 2), so its disagreeing
#  arms are dead code on this path. Renamed from "..._unsupported" to
#  "..._clean" once this stopped being an unsupported shape.
run_json "$loop_branch_case_nested_if" \
  tests/verification_loop_branch_case_nested_if_clean.adb
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_case_nested_if" >/dev/null
grep -F '"kind": "loop-variant", "status": "proved-safe", "method": "external-prover"' \
  "$loop_branch_case_nested_if" >/dev/null

#  A one-sided if (no else) that increments a counter only on the true
#  arm, with the invariant bound genuinely following from the loop guard,
#  is exactly the shape the precise ite-join (VC.Join_On_Condition) exists
#  for: the merged value keeps its relation to the loop guard through an
#  "(ite <cond> <true-term> <false-term>)" SMT term instead of collapsing
#  to a totally unconstrained fresh symbol.
run_json "$loop_branch_ite_precision" \
  tests/verification_loop_branch_ite_precision.adb
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_ite_precision" >/dev/null
grep -F '"kind": "loop-variant", "status": "proved-safe", "method": "external-prover"' \
  "$loop_branch_ite_precision" >/dev/null

#  Same one-sided-if shape, but the increment on the true arm is large
#  enough that the invariant bound is not actually guaranteed by the loop
#  guard -- a real defect. The precise ite-join must never paper over this:
#  it stays unproved, confirming the one-sided (Missing_Term) path of
#  Join_On_Condition doesn't trade soundness for precision.
run_json "$loop_branch_ite_unsafe" \
  tests/verification_loop_branch_ite_unsafe.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_branch_ite_unsafe" >/dev/null
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_branch_ite_unsafe" >/dev/null
if grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_ite_unsafe" >/dev/null; then
   echo "an unsafe one-sided branch increment escaped into a false loop-invariant proof" >&2
   exit 1
fi

#  If the branch condition itself doesn't translate to an SMT term (here,
#  an array-indexed read), Join_On_Condition still builds an ite, but with
#  an anonymous placeholder boolean standing in for the real condition
#  (sound for any selector value, per Join_On_Condition's own reasoning)
#  instead of Cond_Term. This fixture's two arms genuinely disagree on a
#  value the invariant depends on (Extra can go negative on the false
#  arm), so it must stay unproved even though the ite path is taken --
#  confirming the placeholder never manufactures a false proof.
run_json "$loop_branch_ite_cond_unsupported" \
  tests/verification_loop_branch_ite_cond_unsupported.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_branch_ite_cond_unsupported" >/dev/null
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_branch_ite_cond_unsupported" >/dev/null

#  The placeholder selector is still precise, not just safe: a one-sided
#  branch whose condition doesn't translate (again an array-indexed read,
#  mirroring project_bias's own Chain_Generator.adb shape exactly) but
#  whose increment is genuinely bounded by the loop guard alone must now
#  reach proved-safe -- the whole point of not collapsing all the way to
#  a fresh, unconstrained symbol just because Condition itself is opaque.
run_json "$loop_branch_ite_cond_unsupported_precision" \
  tests/verification_loop_branch_ite_cond_unsupported_precision.adb
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_ite_cond_unsupported_precision" >/dev/null

#  Adversarial counterpart: same one-sided, condition-unsupported shape,
#  but the increment (+2) is not actually guaranteed safe by the loop
#  guard (which only ever proves +1 safe). Must stay unproved -- the
#  placeholder selector's added precision must never paper over a real
#  defect in the one-sided Missing_Term path.
run_json "$loop_branch_ite_cond_unsupported_unsafe" \
  tests/verification_loop_branch_ite_cond_unsupported_unsafe.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_branch_ite_cond_unsupported_unsafe" >/dev/null
if grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_branch_ite_cond_unsupported_unsafe" >/dev/null; then
   echo "an unsafe increment behind an untranslatable condition escaped into a false loop-invariant proof" >&2
   exit 1
fi

#  Two leading invariants on the same loop, straight-line body (no branch
#  at all -- this is about Apply_Loop_Invariants/Prove_Header's own setup,
#  not the branch-merge machinery above): the first is plain and always
#  translatable; the second references an indexed array read and can
#  never translate. VC.Assume bails to a totally empty state (VC.Havoc)
#  for the second, and adopting that unconditionally used to erase the
#  first invariant's already-accumulated assumption too, poisoning an
#  otherwise-trivially-provable obligation. The first invariant's own
#  initialization and preservation must both still reach proved-safe;
#  the second, unsupported one is expected to stay unproved for itself.
run_json "$loop_invariant_independent_failure" \
  tests/verification_loop_invariant_independent_failure.adb
grep -F '"kind": "loop-invariant-initialization", "status": "proved-safe"' \
  "$loop_invariant_independent_failure" >/dev/null
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_invariant_independent_failure" >/dev/null
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_invariant_independent_failure" >/dev/null

#  An array-element write inside a loop body must not block invariant
#  preservation / variant progress for obligations that don't depend on the
#  array's contents -- Symbol_For has no support for indexed reads, so
#  skipping the symbolic update for that one statement (while still letting
#  the abstract flow interpreter process it) leaves no stale binding behind.
run_json "$loop_array_write" tests/verification_loop_array_write_clean.adb
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_array_write" >/dev/null
grep -F '"kind": "loop-variant", "status": "proved-safe", "method": "external-prover"' \
  "$loop_array_write" >/dev/null
grep -F '"kind": "postcondition", "status": "proved-safe"' \
  "$loop_array_write" >/dev/null

#  A record-component write is different from an array-element write: unlike
#  an array element, VC_Prover *does* plant a symbolic root for Obj.Field
#  reads, so skipping its update would let a later reference to it resolve
#  to a stale pre-write value -- a real soundness trap. This must keep
#  conservatively bailing to unproved, never proved-safe.
run_json "$loop_record_write" \
  tests/verification_loop_record_write_unsupported.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_record_write" >/dev/null
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_record_write" >/dev/null
if grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_record_write" >/dev/null; then
   echo "a record-component write escaped into a false loop-invariant proof" >&2
   exit 1
fi

#  An unconstrained array parameter's 'Length has no literal value to
#  substitute, but it's always >= 0 by the language itself -- represent it
#  as a fresh symbol lower-bounded at 0 rather than refusing the whole
#  obligation, the same way an ordinary unconstrained scalar formal becomes
#  a symbol elsewhere.
run_json "$loop_length_symbolic" \
  tests/verification_loop_length_symbolic_clean.adb
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_length_symbolic" >/dev/null

#  The fresh 'Length symbol must carry only the bound the language actually
#  guarantees (>= 0), never an unwarranted tighter one -- an empty array is
#  legal, so 'Length >= 1 must stay unproved.
run_json "$length_attribute_unsound" \
  tests/verification_length_attribute_unsound.adb
grep -F '"kind": "assertion", "status": "proved-safe"' \
  "$length_attribute_unsound" | grep -F "Chain'Length >= 0" >/dev/null
if grep -F '"kind": "assertion", "status": "proved-safe"' \
  "$length_attribute_unsound" | grep -F "Chain'Length >= 1" >/dev/null; then
   echo "an unconstrained array's 'Length was given an unwarranted lower bound" >&2
   exit 1
fi

#  A loop-variant expression declared with a dynamic range constraint on an
#  otherwise statically-bounded named type (e.g. "Chain_Len : Natural range
#  0 .. Chain'Length", where Chain is an unconstrained array parameter)
#  must not be refused outright for lacking static bounds -- Ada scalar
#  subtyping only narrows, so the named type's own fully-unwound base
#  range is always a sound fallback envelope. This only asserts the bounds
#  gate is cleared (no "missing-static-bounds" reason code); the SMT
#  solver may still not discharge progress itself.
run_json "$loop_variant_dynamic_bound" \
  tests/verification_loop_variant_dynamic_bound.adb
if grep -F '"kind": "loop-variant"' "$loop_variant_dynamic_bound" |
  grep -F '"reasonCode": "missing-static-bounds"' >/dev/null
then
   echo "a dynamically-constrained loop-variant counter on a statically-bounded named type still refused static bounds" >&2
   exit 1
fi

run_json "$loop_variant_increases" \
  tests/verification_loop_variant_increases.adb
grep -F '"kind": "loop-variant", "status": "proved-safe", "method": "external-prover"' \
  "$loop_variant_increases" | grep -F '"operation": "I"' >/dev/null

#  verification_loop_variant_increases.adb with "I := I + 1" replaced by
#  "I := Integer'Succ (I)" (FP-061): a bare 'Succ-based loop counter used
#  to translate to a Definite_Error -- both sides of the before/after
#  progress comparison collapsed to the identical unconstrained SMT
#  placeholder (the unsupported 'Succ RHS Havoc'd every binding, see
#  quality/known_analysis_issues.tsv), so the goal became a tautological
#  contradiction that read as a *proven* variant violation instead of an
#  untranslated expression. This asserts the strongest possible outcome,
#  proved-safe, not merely "not a false positive".
run_json "$loop_variant_succ" \
  tests/verification_loop_variant_succ.adb
grep -F '"kind": "loop-variant", "status": "proved-safe", "method": "external-prover"' \
  "$loop_variant_succ" | grep -F '"operation": "I"' >/dev/null

run_json "$loop_variant_wrong" \
  tests/verification_loop_variant_wrong_direction.adb
grep -F '"kind": "loop-variant", "status": "definite-error", "method": "external-prover"' \
  "$loop_variant_wrong" | grep -F '"operation": "I"' >/dev/null

run_json "$loop_variant_unsupported" \
  tests/verification_loop_variant_unsupported.adb
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_variant_unsupported" |
  grep -F '"operation": "I ** 2"' |
  grep -F '"reasonCode": "unsupported-operator"' |
  grep -F '"blockingExpression": "I ** 2"' >/dev/null

#  FP-064: indexing into an array slice -- Items (1 .. Last) (1) -- used to
#  be proved safe against the array *type*'s index subtype (Positive),
#  ignoring that the slice's own bounds are 1 .. Last and empty when
#  Last = 0. The scalar domain does not model slice bounds, so the
#  index-check obligation must stay conservative (unproved), never
#  proved-safe. Found on AdaCore SPARK testsuite unit
#  OB26-006__ctex_array_ret_func via benchmarks/spark_testsuite/.
run_json "$slice_index_conservative" \
  tests/verification_slice_index_conservative.adb
grep -F '"kind": "index-check", "status": "unproved"' \
  "$slice_index_conservative" | grep -F '"operation": "1"' >/dev/null
if grep -F '"kind": "index-check", "status": "proved-safe"' \
  "$slice_index_conservative" >/dev/null; then
   echo "an index into an array slice was proved safe against the array" \
     "type's index subtype instead of the slice bounds (FP-064)" >&2
   exit 1
fi

#  A Loop_Invariant is only ever discharged when every loop-body statement
#  before it is itself a leading loop-invariant/loop-variant pragma (see
#  Is_Leading_Loop_Proof_Pragma in flow_interp.adb). This fixture is
#  verification_loop_variant_increases.adb with its two pragmas swapped --
#  Loop_Variant first, Loop_Invariant second, the dominant real-world style
#  (e.g. every one of the EliAvila10/project_bias corpus's 26 loops; see
#  benchmarks/project_bias/). Ada/SPARK attaches no
#  meaning to that ordering, but a prior version of the leading-invariant
#  check only tolerated preceding loop-invariant pragmas, not a preceding
#  loop-variant, so this exact reordering used to leave the invariant
#  non-leading and its preservation permanently unproved -- which then
#  starved the loop-variant progress check of the discharged leading
#  invariant it depends on, even though the variant's own leading check
#  already tolerated either pragma order.
run_json "$loop_variant_leading_order" \
  tests/verification_vc_variant_leading_invariant_order.adb
grep -F '"kind": "loop-invariant-preservation", "status": "proved-safe"' \
  "$loop_variant_leading_order" >/dev/null
grep -F '"kind": "loop-variant", "status": "proved-safe", "method": "external-prover"' \
  "$loop_variant_leading_order" >/dev/null

vc_status=0
ADALANG_CVC5=/nonexistent/cvc5 ADALANG_Z3=/nonexistent/z3 \
  "$analyzer" --verify -q --format=json --output="$vc_unavailable" \
  tests/verification_vc_clean.adb || vc_status=$?
if [ "$vc_status" -gt 1 ]; then
   echo "solver-unavailable run failed with status $vc_status" >&2
   exit "$vc_status"
fi
grep -F '"kind": "assertion", "status": "unproved"' \
  "$vc_unavailable" >/dev/null
if grep -F '"method": "external-prover"' "$vc_unavailable" >/dev/null; then
   echo "unavailable solver produced an external proof result" >&2
   exit 1
fi

#  A goto back up to a label makes a cycle no loop header cuts.
run_json "$unsupported" tests/verification_unsupported.adb
grep -F '"status": "unsupported"' "$unsupported" >/dev/null
if grep -F '"status": "proved-safe"' "$unsupported" >/dev/null; then
   echo "incomplete CFG produced a proved-safe result" >&2
   exit 1
fi

run_json "$loop_stale_init" tests/verification_loop_stale_initialization.adb
grep -F '"kind": "initialization-check", "status": "unproved"' \
  "$loop_stale_init" >/dev/null
if grep -F '"kind": "initialization-check", "status": "definite-error"' \
  "$loop_stale_init" >/dev/null; then
   echo "a read after a dynamically-bounded for-loop write was stuck at" \
     "a Definite_Error recorded from the CFG fixed point's intermediate," \
     "pre-convergence state instead of Verify_Subprogram's final one" >&2
   exit 1
fi

range_status=0
"$analyzer" --verify tests/verification_loop_stale_range_check.adb \
  >"$loop_stale_range" 2>&1 || range_status=$?
if [ "$range_status" -ne 1 ] \
  || [ "$(grep -c '\[Known_Range_Check_Failure\]' "$loop_stale_range")" -ne 1 ]
then
   echo "a range-check violation downstream of a dynamically-bounded" \
     "for-loop was reported more than once, because Verify_Subprogram's" \
     "CFG fixed point revisited the same statement while converging and" \
     "Report_Rule_Violation has no per-run deduplication" >&2
   cat "$loop_stale_range" >&2
   exit 1
fi

run_json "$loop_stale_range_obligation" tests/verification_loop_stale_range.adb
grep -F '"kind": "range-check", "status": "unproved"' \
  "$loop_stale_range_obligation" | grep -F '"operation": "Val"' >/dev/null
if grep -F '"kind": "range-check", "status": "proved-safe"' \
  "$loop_stale_range_obligation" | grep -F '"operation": "Val"' >/dev/null; then
   echo "a range-check downstream of a dynamically-bounded for-loop was" \
     "stuck at a Proved_Safe recorded from the CFG fixed point's" \
     "intermediate, pre-convergence state instead of Verify_Subprogram's" \
     "final one" >&2
   exit 1
fi

run_json "$loop_stale_index" tests/verification_loop_stale_index.adb
grep -F '"kind": "index-check", "status": "unproved"' \
  "$loop_stale_index" | grep -F '"operation": "Idx"' >/dev/null
if grep -F '"kind": "index-check", "status": "proved-safe"' \
  "$loop_stale_index" | grep -F '"operation": "Idx"' >/dev/null; then
   echo "an index-check downstream of a dynamically-bounded for-loop was" \
     "stuck at a Proved_Safe recorded from the CFG fixed point's" \
     "intermediate, pre-convergence state instead of Verify_Subprogram's" \
     "final one" >&2
   exit 1
fi

run_json "$loop_stale_division" tests/verification_loop_stale_division.adb
grep -F '"kind": "division-by-zero", "status": "unproved"' \
  "$loop_stale_division" | grep -F '"operation": "Divisor"' >/dev/null
if grep -F '"kind": "division-by-zero", "status": "proved-safe"' \
  "$loop_stale_division" | grep -F '"operation": "Divisor"' >/dev/null; then
   echo "a division-by-zero check downstream of a dynamically-bounded" \
     "for-loop was stuck at a Proved_Safe recorded from the CFG fixed" \
     "point's intermediate, pre-convergence state instead of" \
     "Verify_Subprogram's final one" >&2
   exit 1
fi

run_json "$loop_stale_overflow" tests/verification_loop_stale_overflow.adb
grep -F '"kind": "integer-overflow", "status": "unproved"' \
  "$loop_stale_overflow" | grep -F '"operation": "X + 1"' >/dev/null
if grep -F '"kind": "integer-overflow", "status": "proved-safe"' \
  "$loop_stale_overflow" | grep -F '"operation": "X + 1"' >/dev/null; then
   echo "an overflow check downstream of a dynamically-bounded for-loop" \
     "was stuck at a Proved_Safe recorded from the CFG fixed point's" \
     "intermediate, pre-convergence state instead of Verify_Subprogram's" \
     "final one" >&2
   exit 1
fi

run_json "$loop_stale_assert" tests/verification_loop_stale_assert.adb
grep -F '"kind": "assertion", "status": "unproved"' \
  "$loop_stale_assert" | grep -F '"operation": "Val <= 2"' >/dev/null
if grep -F '"kind": "assertion", "status": "proved-safe"' \
  "$loop_stale_assert" | grep -F '"operation": "Val <= 2"' >/dev/null; then
   echo "a pragma Assert condition downstream of a dynamically-bounded" \
     "for-loop was stuck at a Proved_Safe recorded from" \
     "Interpret_Proof_Pragma's live, pre-convergence CFG visit instead of" \
     "Verify_Subprogram's final one" >&2
   exit 1
fi

run_json "$loop_stale_precondition" tests/verification_loop_stale_precondition.adb
grep -F '"kind": "precondition", "status": "unproved"' \
  "$loop_stale_precondition" | grep -F '"operation": "Helper (Val)"' >/dev/null
grep -F '"kind": "precondition", "status": "unproved"' \
  "$loop_stale_precondition" | grep -F '"operation": "Helper"' >/dev/null
if grep -F '"kind": "precondition", "status": "proved-safe"' \
  "$loop_stale_precondition" >/dev/null; then
   echo "a call precondition downstream of a dynamically-bounded for-loop" \
     "was stuck at a Proved_Safe recorded from Check_Call_Precondition's" \
     "live, pre-convergence CFG visit instead of Verify_Subprogram's" \
     "final one" >&2
   exit 1
fi

run_json "$global_aspect_clean" \
  tests/verification_global_aspect_reference_clean.adb
if grep -F '"status": "definite-error"' "$global_aspect_clean" >/dev/null; then
   echo "a scalar named only in a nested subprogram declaration's Global" \
     "aspect (never executed at that textual position) was misread as a" \
     "read of the outer object before its real initializing assignment" \
     "later in the enclosing body" >&2
   exit 1
fi

run_json "$global_aspect_guard" \
  tests/verification_global_aspect_reference_guard.adb
grep -F '"kind": "initialization-check", "status": "definite-error"' \
  "$global_aspect_guard" | grep -F '"operation": "Y"' >/dev/null

#  FP-046: "Subp_Name.Param := ...;" inside "procedure Subp_Name (Param :
#  out ...)" -- Ada's general unit-name qualification (RM 8.3), typically
#  used to reach a formal that a same-named component of an enclosing
#  protected/task object would otherwise shadow for simple-name
#  visibility -- was misread by Flow_Interp's own initialization
#  tracking as a read of the (still-uninitialized) parameter rather than
#  a write to it. SPARK_Readiness.Same_Parameter already recognized this
#  shape for --recommended/Uninitialized_Output (FP-011); --verify's own,
#  separate tracking had never received the equivalent fix.
run_json "$own_name_qualifier" tests/verification_own_name_qualifier.adb
if grep -F '"kind": "initialization-check", "status": "definite-error"' \
  "$own_name_qualifier" >/dev/null; then
   echo "an out parameter written through its own subprogram's" \
     "name-qualified form was misread as an uninitialized read (FP-046)" \
     >&2
   cat "$own_name_qualifier" >&2
   exit 1
fi

#  FP-040: a call whose callee is declared in a separate, with'd GNAT
#  project can make Libadalang's own CallExpr.P_Kind raise Property_Error
#  ("undetermined CallExpr kind") when its precise overload resolution
#  fails across the project boundary. Finalize_Node's whole-body walk
#  called P_Kind a second time directly in an if-condition, outside any
#  begin/exception block, so the failure escaped Finalize_Node entirely
#  and aborted the whole file via Process_File's outer handler instead of
#  just this one obligation -- confirmed on a two-project fixture and on
#  cubesatlab/cubedos (benchmarks/cubedos/), where it undercounted
#  --verify's proof obligations on 21 of 49 files. -P is required here
#  (unlike every other fixture in this file) since the bug only manifests
#  across a real project boundary; a project-less bare-file run never
#  exercises it.
status=0
"$analyzer" -P tests/verification_cross_project/main.gpr --verify -q \
  --format=json --output="$cross_project" \
  tests/verification_cross_project/verification_cross_project_clean.adb \
  2>"$cross_project_stderr" || status=$?
if [ "$status" -gt 1 ]; then
   echo "verification run failed for" \
     "verification_cross_project_clean.adb with status $status" >&2
   exit "$status"
fi
if grep -F "Error processing" "$cross_project_stderr" >/dev/null; then
   echo "a call into a separate with'd project aborted the whole file's" \
     "--verify processing instead of just skipping the one affected" \
     "obligation (FP-040)" >&2
   cat "$cross_project_stderr" >&2
   exit 1
fi

#  FP-084: an exception inside the fixed-point run (here a Libadalang
#  property error on a parameter type declared in a spec that is not
#  available) used to finalize with the partial Reachable array, reporting
#  every node the worklist had not yet reached as Unreachable. An aborted
#  run must leave its obligations Unsupported, never Unreachable.
run_json "$aborted_fixpoint" tests/verification_fp084_missing_spec.adb
if grep -F '"status": "unreachable"' "$aborted_fixpoint" >/dev/null; then
   echo "an aborted fixed-point run reported Unreachable obligations (FP-084)" >&2
   exit 1
fi
if ! grep -F '"operation": "Z.F + 1"' "$aborted_fixpoint" |
  grep -F '"status": "unsupported"' >/dev/null
then
   echo "an aborted fixed-point run did not leave its obligation Unsupported (FP-084)" >&2
   exit 1
fi

#  An obligation of the given kind and operation must exist and must not be
#  Proved_Safe: the seeded defect makes it fail at run time, or leaves it
#  beyond what the analysis may claim.
must_not_prove()
{
   report=$1
   kind=$2
   operation=$3
   issue=$4
   found=$(grep -F "\"kind\": \"$kind\"" "$report" |
     grep -F "\"operation\": \"$operation\"" || true)
   if [ -z "$found" ]; then
      echo "$issue: no $kind obligation for '$operation'" >&2
      exit 1
   fi
   if printf '%s\n' "$found" | grep -F '"status": "proved-safe"' >/dev/null
   then
      echo "$issue: false-safe $kind for '$operation'" >&2
      exit 1
   fi
}

#  The positive sibling: the same obligation must still prove, by the named
#  method.
must_prove()
{
   report=$1
   kind=$2
   operation=$3
   method=$4
   issue=$5
   if ! grep -F "\"kind\": \"$kind\"" "$report" |
     grep -F "\"operation\": \"$operation\"" |
     grep -F '"status": "proved-safe"' |
     grep -F "\"method\": \"$method\"" >/dev/null
   then
      echo "$issue: $kind for '$operation' no longer proves by $method" >&2
      exit 1
   fi
}

#  FP-086: "X not in S" where S carries a predicate was translated as a
#  range test, so the solver proved a non-member outside S's range and a
#  division by a value that can be zero safe.
run_json "$fp086" tests/verification_fp086_predicate_membership.adb
for operation in '(Value - 1)' '(Value - 3)' '(Value - 5)' '(Value - 2)'; do
   must_not_prove "$fp086" division-by-zero "$operation" FP-086
done
must_prove "$fp086" division-by-zero '(Value - 11)' abstract-interpretation \
  FP-086
must_prove "$fp086" division-by-zero '(Value - 7)' external-prover FP-086

#  FP-087: a subtype or array bound that reads a variable was re-evaluated
#  with the variable's current value instead of its value at elaboration.
run_json "$fp087" tests/verification_fp087_stale_bound.adb
must_not_prove "$fp087" range-check 50 FP-087
must_not_prove "$fp087" index-check 60 FP-087
must_prove "$fp087" range-check 7 abstract-interpretation FP-087
must_prove "$fp087" index-check 8 abstract-interpretation FP-087

#  FP-088: an array whose bounds no declaration fixes was checked against
#  its index subtype, and a target range with one unknown bound was proved
#  from the other alone.
run_json "$fp088" tests/verification_fp088_unknown_array_bounds.adb
must_not_prove "$fp088" index-check Position FP-088
must_not_prove "$fp088" index-check 2 FP-088
must_not_prove "$fp088" index-check 3 FP-088
must_not_prove "$fp088" range-check Position FP-088
must_not_prove "$fp088" assertion "Text'First = 1" FP-088
must_prove "$fp088" index-check 4 abstract-interpretation FP-088
must_prove "$fp088" index-check 6 abstract-interpretation FP-088
for operation in 20 30; do
   if ! grep -F '"kind": "index-check"' "$fp088" |
     grep -F "\"operation\": \"$operation\"" |
     grep -F '"status": "definite-error"' >/dev/null
   then
      echo "an index outside an object's own static index constraint was" \
        "not reported as a definite error (FP-088)" >&2
      exit 1
   fi
done

#  FP-089: Standard's character types were bounded by the single
#  placeholder literal of Libadalang's own declaration, so any two
#  Character values were provably equal.
run_json "$fp089" tests/verification_fp089_character_positions.adb
must_not_prove "$fp089" assertion 'Left = Right' FP-089
must_not_prove "$fp089" assertion "Wide = Wide_Character'Val (65)" FP-089
must_prove "$fp089" assertion 'Tint in Red .. Blue' external-prover FP-089

#  Membership tests narrow the tested identifier's interval on both
#  outcomes, without ever narrowing past what the test establishes.
run_json "$membership" tests/verification_membership_narrowing.adb
for operation in Divisor Free '(Free - 11)' '(Free + 1)' '(Bounded - 2)' \
  '(Bounded - 6)' '(Bounded + 1)'
do
   must_prove "$membership" division-by-zero "$operation" \
     abstract-interpretation "membership narrowing"
done
for operation in '(Free - 5)' '(Free - 9)' '(Free - 20)' '(Free - 7)' \
  '(Bounded - 8)' '(Bounded - 1)' '(Bounded - 3)'
do
   must_not_prove "$membership" division-by-zero "$operation" \
     "membership narrowing"
done

#  The parameter of a loop over an array object's own range indexes that
#  object; nothing else about a loop makes an index safe.
run_json "$own_range" tests/verification_pp_index_own_range.adb
for operation in Own Spelled Backward Row Column; do
   must_prove "$own_range" index-check "$operation" static-evaluation \
     "own-range index"
done
for operation in Foreign Mixed 'Shifted + 1' Shadowed Swapped; do
   must_not_prove "$own_range" index-check "$operation" "own-range index"
done
#  Inside a loop over the second dimension that dimension is not empty, so
#  its own first index is within it.
must_prove "$own_range" index-check "Cells'First (2)" external-prover \
  "own-range index"

#  FP-090: a symbol minted at a merge point kept the bounds of the first
#  visit, so a variable changed on a later loop iteration was still
#  confined to its pre-loop value at the loop exit.
run_json "$fp090" tests/verification_fp090_loop_exit_roots.adb
for operation in Early Late '(Count - 3)'; do
   must_not_prove "$fp090" division-by-zero "$operation" FP-090
done
must_prove "$fp090" division-by-zero Kept abstract-interpretation FP-090

#  FP-091: modular "+", "-" and "*" were evaluated as mathematical
#  integers, on both the abstract path and the solver path, so a sum that
#  wraps to zero was a provably nonzero divisor.
run_json "$fp091" tests/verification_fp091_modular_wrap.adb
for operation in '(Top + 1)' '(Half * 2)' '(Any + 1)' 'Integer (Any + 2)'; do
   must_not_prove "$fp091" division-by-zero "$operation" FP-091
done
must_prove "$fp091" division-by-zero '(Low + 1)' abstract-interpretation \
  FP-091
must_prove "$fp091" division-by-zero 'Integer (Any * 2 + 1)' \
  external-prover FP-091

#  FP-092: facts were kept about objects that another name can change (a
#  renaming, an address overlay) or that can change with no name at all
#  (volatile, atomic).
run_json "$fp092" tests/verification_fp092_untracked_objects.adb
for operation in Renamed View Overlaid Device Shared; do
   must_not_prove "$fp092" division-by-zero "$operation" FP-092
done
must_prove "$fp092" division-by-zero Plain abstract-interpretation FP-092

#  FP-093: a function called inside an expression was assumed to change
#  nothing, so a fact about an object it writes survived the call.
run_json "$fp093" tests/verification_fp093_function_side_effects.adb
for operation in Level '(Level + 0)' '(Level - 0)' '(0 + Level)' \
  '(Level * 1)'
do
   must_not_prove "$fp093" division-by-zero "$operation" FP-093
done
must_prove "$fp093" division-by-zero Other abstract-interpretation FP-093

#  FP-094: Initialize and Finalize of a controlled object, and component
#  defaults that call a function, run where the source shows no call.
status=0
"$analyzer" --verify -q --format=json --output="$fp094" \
  tests/verification_fp094_implicit_code.ads \
  tests/verification_fp094_implicit_code.adb || status=$?
if [ "$status" -gt 1 ]; then
   echo "verification run failed for verification_fp094_implicit_code" \
     "with status $status" >&2
   exit "$status"
fi
for operation in '(Level + 0)' '(Level - 0)' '(0 + Level)'; do
   must_not_prove "$fp094" division-by-zero "$operation" FP-094
done
must_prove "$fp094" division-by-zero Level abstract-interpretation FP-094

#  Rule findings under --verify are reported from converged states only:
#  the fixed-point run first reaches the code after a loop, and a while
#  loop's own condition, with the values from before the loop, which made
#  a divisor look like a known zero and the condition look constant.
run_json "$converged" tests/verification_converged_rule_findings.adb
for finding in '"line": 17' '"line": 20'; do
   if grep -E '"ruleId": "(Division_By_Zero|Constant_Condition)"' \
     "$converged" | grep -F "$finding," >/dev/null
   then
      echo "a rule finding was reported from a state the fixed point had" \
        "not converged on ($finding)" >&2
      exit 1
   fi
done
grep -F '"ruleId": "Constant_Condition"' "$converged" |
  grep -F '"line": 24,' >/dev/null
grep -F '"ruleId": "Division_By_Zero"' "$converged" |
  grep -F '"line": 27,' >/dev/null

#  A call that resolves to a null procedure or an expression function
#  completing an earlier declaration is checked against the precondition on
#  that declaration; it used to get no precondition obligation at all.
status=0
"$analyzer" --verify -q --format=json --output="$completion" \
  tests/verification_null_completion_contracts.ads \
  tests/verification_null_completion_contracts.adb || status=$?
if [ "$status" -gt 1 ]; then
   echo "verification run failed for" \
     "verification_null_completion_contracts with status $status" >&2
   exit "$status"
fi
must_prove "$completion" precondition 'Needs_Positive (7)' \
  contract-transfer "completion contracts"
must_prove "$completion" precondition 'Needs_Ordered (1, 2)' \
  contract-transfer "completion contracts"
must_prove "$completion" precondition 'Half (4)' contract-transfer \
  "completion contracts"
must_not_prove "$completion" precondition 'Needs_Positive (N)' \
  "completion contracts"
for operation in 'Needs_Ordered (High => 1, Low => 2)' 'Half (1)'; do
   if ! grep -F '"kind": "precondition"' "$completion" |
     grep -F "\"operation\": \"$operation\"" |
     grep -F '"status": "definite-error"' >/dev/null
   then
      echo "a false precondition on a completed declaration was not" \
        "reported: $operation" >&2
      exit 1
   fi
done

#  A function in SPARK has no side effects. SPARK_Mode can come from a
#  pragma before the unit or from the project's configuration pragmas; a
#  unit that opts out, or the same sources read without the project, get
#  no such credit.
status=0
"$analyzer" -P tests/verification_spark_mode_sources/main.gpr --verify -q \
  --format=json --output="$spark_project" \
  tests/verification_spark_mode_sources/verification_spark_mode_sources.adb \
  || status=$?
if [ "$status" -gt 1 ]; then
   echo "verification run failed for verification_spark_mode_sources" \
     "with status $status" >&2
   exit "$status"
fi
must_prove "$spark_project" division-by-zero Unit_Level \
  abstract-interpretation "SPARK_Mode before the unit"
must_prove "$spark_project" division-by-zero Project_Level \
  abstract-interpretation "SPARK_Mode from configuration pragmas"
must_not_prove "$spark_project" division-by-zero Unmarked_Level \
  "SPARK_Mode (Off)"

status=0
"$analyzer" --verify -q --format=json --output="$spark_bare" \
  tests/verification_spark_mode_sources/by_project.ads \
  tests/verification_spark_mode_sources/by_unit.ads \
  tests/verification_spark_mode_sources/unmarked.ads \
  tests/verification_spark_mode_sources/verification_spark_mode_sources.adb \
  || status=$?
if [ "$status" -gt 1 ]; then
   echo "verification run failed for verification_spark_mode_sources" \
     "(no project) with status $status" >&2
   exit "$status"
fi
must_prove "$spark_bare" division-by-zero Unit_Level \
  abstract-interpretation "SPARK_Mode before the unit"
must_not_prove "$spark_bare" division-by-zero Project_Level \
  "no project, no configuration pragmas"

#  FP-097: an expanded name ("Pkg.Obj", "Subp.Local") was not recognized
#  as the object it denotes, so a write through it left the fact held
#  under the direct name in place.
run_json "$fp097" tests/verification_fp097_expanded_names.adb
must_not_prove "$fp097" division-by-zero Level FP-097
must_not_prove "$fp097" division-by-zero Local FP-097
must_prove "$fp097" division-by-zero State.Other abstract-interpretation \
  FP-097

#  FP-098: a symbol minted on a path the interval domain found infeasible
#  (the body of a loop over an empty range) kept its empty bounds after
#  the join, which made every later goal follow from a contradiction.
run_json "$fp098" tests/verification_fp098_infeasible_roots.adb
for operation in '(Kept - 1)' Divisor '(Divisor - 1)'; do
   must_not_prove "$fp098" division-by-zero "$operation" FP-098
done
must_prove "$fp098" division-by-zero '(Kept + 1)' abstract-interpretation \
  FP-098

#  FP-099: a function call in a condition writes its "out" actuals, so a
#  later read of one is not a read of an uninitialized object; it is not
#  proved either. A read of an object nothing writes is
#  still a definite error.
run_json "$fp099" tests/verification_fp099_function_out_actual.adb
for operation in Found Later; do
   must_not_prove "$fp099" initialization-check "$operation" FP-099
   if grep -F '"kind": "initialization-check"' "$fp099" |
     grep -F "\"operation\": \"$operation\"" |
     grep -F '"status": "definite-error"' >/dev/null
   then
      echo "FP-099: the actual of a function's writable parameter" \
        "('$operation') was reported as uninitialized" >&2
      exit 1
   fi
done
if ! grep -F '"kind": "initialization-check"' "$fp099" |
  grep -F '"operation": "Never"' |
  grep -F '"status": "definite-error"' >/dev/null
then
   echo "FP-099: a read of an object nothing writes is no longer a" \
     "definite error" >&2
   exit 1
fi

#  FP-100: an initial value whose computation always overflows never
#  reaches its range check, so the overflow is the only definite error
#  there. A value computed without overflow that is outside the subtype
#  still fails its range check.
run_json "$fp100" tests/verification_fp100_overflow_before_range.adb
grep -F '"kind": "integer-overflow"' "$fp100" |
  grep -F "\"operation\": \"Ident (Integer'Last) + 1\"" |
  grep -F '"status": "definite-error"' >/dev/null
if grep -F '"kind": "range-check"' "$fp100" |
  grep -F "\"operation\": \"Ident (Integer'Last) + 1\"" |
  grep -F '"status": "definite-error"' >/dev/null
then
   echo "FP-100: a range check behind an overflow that always occurs was" \
     "reported as a second definite error" >&2
   exit 1
fi
if ! grep -F '"kind": "range-check"' "$fp100" |
  grep -F '"operation": "Ident (5) + 20"' |
  grep -F '"status": "definite-error"' >/dev/null
then
   echo "FP-100: a value outside its subtype, computed without overflow," \
     "is no longer a definite range-check error" >&2
   exit 1
fi

#  An index into an object whose bounds no declaration fixes proves
#  against the object's own 'First and 'Last, and only against those.
run_json "$symbolic_bounds" tests/verification_pp_index_symbolic_bounds.adb
for operation in Given Probe "Data'First + 1" 'Step + 1'; do
   must_prove "$symbolic_bounds" index-check "$operation" external-prover \
     "symbolic array bounds"
done
for operation in 'Given + 1' 'Given + 0' 'Probe + 0' "Data'Last + 1" \
  'Step + 2'
do
   must_not_prove "$symbolic_bounds" index-check "$operation" \
     "symbolic array bounds"
done

#  Each dimension of such an object has bounds of its own: a fact about
#  the second dimension proves an index there, and nothing about the first.
run_json "$symbolic_dimensions" tests/verification_symbolic_bounds_dimensions.adb
for operation in Row Col Probe "Data'First (2) + 1" 'C + 1'; do
   must_prove "$symbolic_dimensions" index-check "$operation" \
     external-prover "symbolic array bounds, second dimension"
done
for operation in 'Col + 0' 'Row + 0' 'Probe + 0' "Data'Last (2) + 1" \
  "Data'First (1) + 1" 'C + 2' 'C + 1 - 0'
do
   must_not_prove "$symbolic_dimensions" index-check "$operation" \
     "symbolic array bounds, second dimension"
done

#  An object of an unconstrained array subtype has the bounds of its
#  initial value: a string literal's, or those of the object it copies. An
#  index outside them is a definite error; an object initialized from a
#  formal has bounds nothing fixes.
run_json "$initializer_bounds" tests/verification_initializer_bounds.adb
for operation in 4 3 6 15; do
   must_prove "$initializer_bounds" index-check "$operation" \
     abstract-interpretation "initializer bounds"
done
for operation in 5 '2 + 2' 2 1 '1 + 0'; do
   must_not_prove "$initializer_bounds" index-check "$operation" \
     "initializer bounds"
done

#  FP-101: the statements after an "if" whose branch has two statements
#  were visited before the branches were joined, and the second visit
#  joined its state with the first, which left related objects unrelated.
#  A branch that cannot be taken then looked live, and a division by an
#  always-zero divisor in it was a definite error. The same division where
#  it can run still is one.
run_json "$fp101" tests/verification_fp101_branch_then_related.adb
must_prove "$fp101" division-by-zero '(Y - X + 1)' external-prover FP-101
must_not_prove "$fp101" division-by-zero '(X - 1)' FP-101
if grep -F '"kind": "division-by-zero"' "$fp101" |
  grep -F '"operation": "(N - N)"' |
  grep -F '"status": "definite-error"' >/dev/null
then
   echo "FP-101: a division in a branch that cannot be taken was reported" \
     "as a definite error" >&2
   exit 1
fi
if ! grep -F '"kind": "division-by-zero"' "$fp101" |
  grep -F '"operation": "(N - N - 0)"' |
  grep -F '"status": "definite-error"' >/dev/null
then
   echo "FP-101: a division by an always-zero divisor on a live branch is" \
     "no longer a definite error" >&2
   exit 1
fi

#  A precondition is evaluated in the caller's state, so one that reads a
#  global is decided; on a recursive call the formals take the actuals'
#  values instead of keeping what the caller knows about its own.
status=0
"$analyzer" --verify -q --format=json --output="$pre_globals" \
  tests/verification_precondition_globals.ads \
  tests/verification_precondition_globals.adb || status=$?
if [ "$status" -gt 1 ]; then
   echo "verification run failed for verification_precondition_globals" \
     "with status $status" >&2
   exit "$status"
fi
must_prove "$pre_globals" precondition 'Needs_Above (4)' contract-transfer \
  "precondition over a global"
must_not_prove "$pre_globals" precondition 'Needs_Above (5)' \
  "precondition over a global"
must_not_prove "$pre_globals" precondition 'Needs_Above (3)' \
  "precondition over a global"
must_not_prove "$pre_globals" precondition 'Count_Down (X - X)' \
  "recursive precondition"

# FP-108: a nested expression function is evaluated where it is called, not
# where it is declared. Divisor is zero at the declarations and two at the
# calls, so the division and the indexing are neither certain failures nor
# proved.
run_json "$deferred" tests/verification_deferred_evaluation.adb
if grep -F '"status": "definite-error"' "$deferred" >/dev/null; then
   echo "a nested expression function was checked in the state at its" \
     "declaration instead of the unknown one at its calls" >&2
   exit 1
fi
must_not_prove "$deferred" division-by-zero 'Divisor' \
  "division in a nested expression function"
must_not_prove "$deferred" index-check 'Divisor' \
  "indexing in a nested expression function"

# Termination: a function, and a procedure with Always_Terminates, is shown
# to return when its loops are bounded, it is not recursive and what it
# calls returns. The subprograms that are not are in the mutation manifest.
run_json "$termination" tests/verification_termination.adb
for subprogram in Leaf Counted Through_Calls Settle; do
   must_prove "$termination" termination "$subprogram" flow-analysis \
     "termination of a subprogram that returns"
done
run_json "$termination_iteration" tests/verification_termination_iteration.adb
for subprogram in Largest All_Small; do
   must_prove "$termination_iteration" termination "$subprogram" \
     flow-analysis "termination of an iteration over an array"
done

# Global aspects: each one below covers what its subprogram reads and
# writes, directly, through the aspects of what it calls, or through the
# body of a callee that has none. The ones that do not are in the mutation
# manifest.
run_json "$flow_contracts" tests/verification_flow_contracts.adb
for subprogram in Copy Bump Checked Scaled Through By_Body Nothing; do
   must_prove "$flow_contracts" data-dependencies "Global of $subprogram" \
     flow-analysis "a Global aspect that holds"
done
must_prove "$flow_contracts" initialization-check Result flow-analysis \
  "an Output global assigned on every path"

# An expression function is verified from its own entry state: the subtypes
# of its parameters and its precondition. A call inside a precondition is
# checked on entry, under the guard that stands before it; one inside a
# postcondition at the exit. The unprotected variants are in the mutation
# manifest.
run_json "$expression_functions" tests/verification_expression_functions.adb
must_prove "$expression_functions" division-by-zero Divisor \
  abstract-interpretation "division under an expression function's precondition"
must_prove "$expression_functions" index-check Position \
  abstract-interpretation "indexing under an expression function's precondition"
must_prove "$expression_functions" range-check Bounded \
  abstract-interpretation "actual parameter under an expression function's precondition"
must_prove "$expression_functions" precondition 'Needs (Value)' \
  contract-transfer "guarded call in a precondition"
must_prove "$expression_functions" precondition 'Ratio (Value, 2)' \
  contract-transfer "call in a postcondition"

# A call to a function of its arguments is a term. What the caller's
# precondition says of an object is what the callee's asks of it, the
# arguments given by name or by position; inside a precondition, the
# operand before a call is the call's own precondition. The cases where the
# object has changed, or the function is not one of its arguments, are in
# the mutation manifest.
run_json_pair()
{
   output=$1
   unit=$2
   status=0
   "$analyzer" --verify -q --format=json --output="$output" \
     "$unit.ads" "$unit.adb" || status=$?
   if [ "$status" -gt 1 ]; then
      echo "verification run failed for $unit with status $status" >&2
      exit "$status"
   fi
}

run_json_pair "$function_terms" tests/verification_function_terms
for operation in 'Step (Whole)' 'Fill (Both, Need)' \
  'Fill (Need => Need, Ctx => Named)' 'Step (Kept)' 'Left (Kept)' \
  'Step (Again)'
do
   must_prove "$function_terms" precondition "$operation" external-prover \
     "a function of its arguments as a term"
done
for operation in 'Step (Ctx => Again)' 'Step (Other)' 'Fill (Sized, More)' \
  'Step (Written)' 'Step (Changed)' 'Step (Replaced)' 'Step (Repeated)' \
  'Step (Joined)' 'Left (Loose)' 'Fire (Aimed)'
do
   must_not_prove "$function_terms" precondition "$operation" \
     "a function term about another value"
done

# A procedure call with known effects leaves what is known of the caller's
# own scalars that it does not name, in straight-line code and in a loop
# whose invariant relates them.
run_json_pair "$call_frame" tests/verification_call_frame
must_prove "$call_frame" assertion 'Offset + Remaining = Length' \
  external-prover "a relation between locals after a call"
must_prove "$call_frame" assertion 'Remaining = Length - Offset' \
  external-prover "a relation between locals after two calls"
must_prove "$call_frame" loop-invariant-preservation \
  'Offset + Remaining = Length' external-prover \
  "a loop invariant over locals with calls in the body"

# FP-110: the symbols of two objects declared at the same line and column
# of two files had one name, and what the precondition says of one
# parameter was taken for the other.
run_json_pair "$fp110" tests/verification_fp110_same_position
must_not_prove "$fp110" assertion 'Other > 5' FP-110
must_prove "$fp110" assertion 'Checked > 5' abstract-interpretation FP-110

# The postcondition of a callee is assumed after the call, of the object
# the call wrote and of the scalars it cannot have changed: a chain of
# calls is proved link by link, after a callee of which nothing else is
# known too, and a loop invariant is preserved by the call that
# re-establishes it. The cases where the fact is about something else are
# in the mutation manifest.
run_json_pair "$call_postcondition" tests/verification_call_postcondition
for operation in 'Step (First)' 'Step (Ctx => First)' \
  'Reserve (Sized, Count)' 'Fill (Sized, Count)' 'Step (Loaded)' \
  'Step (Turning)'
do
   must_prove "$call_postcondition" precondition "$operation" \
     external-prover "a callee's postcondition after the call"
done
must_prove "$call_postcondition" loop-invariant-preservation \
  'Ready (Turning)' external-prover \
  "a loop invariant re-established by a callee's postcondition"

# FP-112: the checks inside the prefix of 'Old and of 'Loop_Entry were
# decided in the state of the place where the attribute is written. The
# prefix of 'Old is evaluated on entry, where the precondition is all that
# holds, and that of 'Loop_Entry when the loop is entered.
run_json_pair "$fp112" tests/verification_fp112_earlier_prefix
must_not_prove "$fp112" division-by-zero Divisor FP-112
must_not_prove "$fp112" integer-overflow 'Addend + 1' FP-112
must_not_prove "$fp112" range-check Converted FP-112
must_not_prove "$fp112" precondition 'Positive_Only (Passed)' FP-112
must_not_prove "$fp112" initialization-check Late FP-112
must_not_prove "$fp112" division-by-zero Zeroed FP-112
must_not_prove "$fp112" division-by-zero Inner FP-112
must_prove "$fp112" precondition 'Positive_Only (Required)' \
  contract-transfer FP-112
must_prove "$fp112" division-by-zero Nonzero abstract-interpretation FP-112
must_prove "$fp112" division-by-zero Steady abstract-interpretation FP-112
must_prove "$fp112" initialization-check Kept flow-analysis FP-112
if grep -F '"status": "definite-error"' "$fp112" >/dev/null; then
   echo "FP-112: a check inside an 'Old prefix is a definite error in the" \
     "state of the exit" >&2
   exit 1
fi

# FP-113: a subtype bound written with the arithmetic of a modular type
# was computed without wrapping: 200 + 100 of a "mod 256" type is 44, and
# was taken for 300.
run_json_pair "$fp113" tests/verification_fp113_modular_bound
for operation in Summed Negated Doubled Chained; do
   must_not_prove "$fp113" range-check "$operation" FP-113
done
must_not_prove "$fp113" index-check Position FP-113
must_prove "$fp113" range-check Fitting abstract-interpretation FP-113
must_prove "$fp113" range-check Small abstract-interpretation FP-113
must_prove "$fp113" index-check Inside abstract-interpretation FP-113
#  A named number written with that arithmetic: Libadalang gives every
#  operator of a number declaration as universal_integer.
must_not_prove "$fp113" range-check Numbered FP-113
must_not_prove "$fp113" range-check Passed FP-113
must_prove "$fp113" range-check Tiny abstract-interpretation FP-113
if grep -F '"status": "definite-error"' "$fp113" >/dev/null; then
   echo "FP-113: a value within a wrapped bound is a definite error" >&2
   exit 1
fi

# A quantified expression in a Loop_Invariant or in an Assert_And_Cut put
# the whole subprogram outside the verification subset: the pragma names
# were compared in a spelling they are never given in.
run_json_pair "$quantified_invariant" tests/verification_quantified_invariant
if grep -F '"status": "unsupported"' "$quantified_invariant" >/dev/null; then
   echo "a quantified loop invariant puts its subprogram outside the" \
     "verification subset" >&2
   exit 1
fi
for kind in loop-invariant-initialization loop-invariant-preservation; do
   must_prove "$quantified_invariant" "$kind" \
     'for all I in 1 .. 10 => I < Steady' external-prover \
     "a quantified loop invariant"
done
must_prove "$quantified_invariant" division-by-zero Steady \
  abstract-interpretation "a quantified loop invariant"
must_not_prove "$quantified_invariant" loop-invariant-preservation \
  'for all J in 1 .. 10 => J < Falling' "a quantified loop invariant"
must_not_prove "$quantified_invariant" loop-invariant-preservation \
  'for all K in 1 .. Growing => K <= 10' "a quantified loop invariant"
must_not_prove "$quantified_invariant" loop-invariant-initialization \
  'for all L in 1 .. 10 => Low > L' "a quantified loop invariant"
must_not_prove "$quantified_invariant" division-by-zero Low \
  "a quantified loop invariant"
must_not_prove "$quantified_invariant" division-by-zero '(M - 5)' \
  "a quantified loop invariant"
must_not_prove "$quantified_invariant" assertion \
  'for all N in 1 .. 10 => Short > N' "a quantified Assert_And_Cut"
must_not_prove "$quantified_invariant" division-by-zero Short \
  "a quantified Assert_And_Cut"

# A name written with its package in front of it is the entity it names,
# an enumeration literal or a named number as much as an object, and a
# named number is its value: what is said of "Pkg.Literal" is said of the
# literal, and "Value < Limit" bounds Value.
run_json_pair "$named_values" tests/verification_named_values
must_prove "$named_values" precondition \
  'Size (Ctx, Verification_Named_Values.F_B)' external-prover \
  "an expanded name of a literal"
must_prove "$named_values" assertion \
  'Copy = Verification_Named_Values.F_B' external-prover \
  "an expanded name of a literal"
must_prove "$named_values" assertion \
  'Copy /= Verification_Named_Values.F_C' external-prover \
  "an expanded name of a literal"
must_prove "$named_values" assertion 'Value < Limit' \
  abstract-interpretation "the value of a named number"
must_prove "$named_values" assertion 'Small < 3' external-prover \
  "the value of a named number"
must_prove "$named_values" division-by-zero \
  '(Verification_Named_Values.Limit - Value)' abstract-interpretation \
  "the value of a named number"
must_not_prove "$named_values" precondition \
  'Size (Ctx, Verification_Named_Values.F_C)' \
  "an expanded name of another literal"
must_not_prove "$named_values" assertion \
  'Copy = Verification_Named_Values.F_A' \
  "an expanded name of another literal"
for operation in 'Above < Limit - 1' 'Middle < 2' 'Octet <= Wrapped' \
  'Integer (Ratio) = 2'
do
   must_not_prove "$named_values" assertion "$operation" \
     "the value of a named number"
done
must_not_prove "$named_values" division-by-zero '(Exact - Limit + 1)' \
  "the value of a named number"

# A goto to a label further down is one more way into that label, and no
# longer puts the subprogram outside the verification subset. What holds at
# the label is what holds on every way in; what follows the goto is reached
# only another way.
run_json_pair "$forward_goto" tests/verification_forward_goto
if grep -F '"status": "unsupported"' "$forward_goto" >/dev/null; then
   echo "a goto to a label further down puts its subprogram outside the" \
     "verification subset" >&2
   exit 1
fi
must_prove "$forward_goto" division-by-zero Either abstract-interpretation \
  "a goto to a label further down"
must_prove "$forward_goto" division-by-zero Five abstract-interpretation \
  "a goto to a label further down"
must_prove "$forward_goto" postcondition 'Same = 2' abstract-interpretation \
  "a goto to a label further down"
grep -F '"kind": "range-check"' "$forward_goto" |
  grep -F '"operation": "0"' |
  grep -F '"status": "unreachable"' >/dev/null
for operation in Skipped Last Value Guarded; do
   must_not_prove "$forward_goto" division-by-zero "$operation" \
     "a goto to a label further down"
done
must_not_prove "$forward_goto" initialization-check Unset_Result \
  "a goto to a label further down"
must_not_prove "$forward_goto" postcondition 'Differs = 2' \
  "a goto to a label further down"
must_not_prove "$forward_goto" loop-invariant-preservation 'Kept >= 0' \
  "a goto to a label further down"

# A loop or a block with a name, and an exit that names the loop it leaves,
# no longer put the subprogram outside the verification subset. An exit
# that names an outer loop goes past what the outer loop's body does after
# the inner loop.
run_json_pair "$named_loops" tests/verification_named_loops
if grep -F '"status": "unsupported"' "$named_loops" >/dev/null; then
   echo "a named loop or block puts its subprogram outside the" \
     "verification subset" >&2
   exit 1
fi
must_prove "$named_loops" division-by-zero Passed abstract-interpretation \
  "an exit that names a loop"
must_not_prove "$named_loops" division-by-zero Skipped \
  "an exit that names a loop"
must_not_prove "$named_loops" initialization-check Unset_Result \
  "an exit that names a loop"
must_not_prove "$named_loops" postcondition 'Differs = 2' \
  "an exit that names a loop"

# T'Size of a static discrete subtype is a number: the Size its first
# subtype is given, or the bits its values take (RM 13.3(55)). The values
# asked for are those GNAT gives.
run_json_pair "$type_size" tests/verification_type_size
for size in "Byte'Size = 8" "Verification_Type_Size.Byte'Size = 8" \
  "Wide'Size = 64" "Decimal'Size = 4" "Percent'Size = 7" "Signed'Size = 4" \
  "Stored'Size = 16" "Claused'Size = 24" "Colour'Size = 2" "Same'Size = 8" \
  "Nibble'Size = 4" "Kept'Size = 16" "Cut'Size = 2" "Nothing'Size = 0" \
  "Derived'Size = 16" "Tight'Size = 2" "Shorter'Size = 4" \
  "Length'Size = 31" "Natural'Size = 31" "Integer'Size = 32" \
  "Boolean'Size = 1"
do
   must_prove "$type_size" assertion "$size" abstract-interpretation \
     "the size of a static discrete subtype"
done
must_prove "$type_size" division-by-zero "Byte'Size" \
  abstract-interpretation "the size of a static discrete subtype"
for size in "Nibble'Size = 8" "Cut'Size = 16" "Percent'Size = 8" \
  "Signed'Size = 3" "Shorter'Size = 7" "Decimal'Size = 8" \
  "Positive'Size = 32" "Stored'Size = 7" "Tight'Size = 16" \
  "Coded'Size = 1" "Warm'Size = 2" "Character'Size = 1" "Item'Size = 4"
do
   must_not_prove "$type_size" assertion "$size" \
     "the size of a static discrete subtype"
done

# FP-114: a state seen while a loop is iterated to its fixed point has not
# settled. An assertion that is false of it is not a definite error, and a
# proof of the same assertion from another such state is no contradiction.
# The subprogram used to be given up for one, every obligation Unsupported
# but the definite errors recorded until then.
run_json_pair "$provisional_error" tests/verification_provisional_error
if grep -F '"status": "unsupported"' "$provisional_error" >/dev/null; then
   echo "a provisional definite error put the subprogram outside the" \
     "verification subset" >&2
   exit 1
fi
if grep -F '"status": "definite-error"' "$provisional_error" >/dev/null; then
   echo "an assertion that holds is a definite error on the showing of a" \
     "state that had not settled" >&2
   exit 1
fi
must_prove "$provisional_error" loop-invariant-initialization \
  "Factor_Index - Product_Index = Data'Last - Product_Pivot + 1" \
  external-prover "a state that has not settled"
must_not_prove "$provisional_error" assertion 'Count >= 1' FP-114
must_prove "$provisional_error" division-by-zero Count \
  abstract-interpretation FP-114

# FP-115: True and False were recognized by their spelling. A parameter or
# a constant so named hides the literal, and holds what it holds.
run_json "$fp115" tests/verification_fp115_hidden_literal.adb
must_not_prove "$fp115" assertion 'not False' FP-115
must_not_prove "$fp115" assertion 'True' FP-115
must_not_prove "$fp115" division-by-zero Count FP-115
if grep -F '"operation": "Count"' "$fp115" |
  grep -F '"status": "unreachable"' >/dev/null
then
   echo "FP-115: the branch a parameter named False guards is unreachable" >&2
   exit 1
fi
must_prove "$fp115" assertion 'Standard.True' abstract-interpretation FP-115
must_prove "$fp115" assertion 'not Standard.False' abstract-interpretation \
  FP-115

# FP-116: an operator symbol was read as the operation it stands for where
# a declaration defines a function for it. None of the functions of the
# fixture computes what its symbol says, and no claim that reads true by
# the symbols holds.
run_json_pair "$fp116" tests/verification_fp116_declared_operator
for claim in 'Integer (Two + Three) = 5' 'Integer (Two * Three) = 6' \
  'Integer (Two mod Three) = 2' 'Integer (Two ** Exponent) = 4' \
  'Integer (-Two) /= 2' 'Integer (abs Two) = 2' 'Two < Three' \
  'Integer (Left) >= Integer (Right)' 'Two = Two' 'not (Two /= Two)' \
  'Integer (Left) /= Integer (Right)' 'Two + Three > Two' \
  'Two + Three in Fifth' "Buffer'Last = 5" 'Integer (Low + High) = 5' \
  'Integer (Two + Offset) = 5' 'Small + Large = 5' 'Yes and Yes' \
  'not (No or No)' 'not Off' 'On xor Idle'
do
   must_not_prove "$fp116" assertion "$claim" FP-116
done
must_not_prove "$fp116" index-check 4 FP-116
must_not_prove "$fp116" range-check 4 FP-116
# The claims that hold are not refuted either, and a right operand of zero
# is no error of a function called "/".
if grep -F '"status": "definite-error"' "$fp116" >/dev/null; then
   echo "FP-116: a definite error where a declared operator is called" >&2
   exit 1
fi
# Such a call has no division check and no overflow check of its own: what
# the function asks of its operands is its precondition, an obligation at
# the operator.
if grep -F '"kind": "division-by-zero"' "$fp116" >/dev/null ||
  grep -F '"kind": "integer-overflow"' "$fp116" |
    grep -F 'verification_fp116_declared_operator.adb"' >/dev/null
then
   echo "FP-116: a division or overflow check on a declared operator" >&2
   exit 1
fi
if [ "$(grep -F '"kind": "precondition"' "$fp116" |
          grep -Fc '"operation": "/"')" -ne 2 ]
then
   echo "FP-116: no precondition obligation at a declared operator" >&2
   exit 1
fi

# The length of an array is converted to the integer type its context
# expects, and the conversion is checked. One range check at each length
# of the first procedure of the fixture, none at those of the second but
# the check that was there before: the assignment's, the actual's, the
# conversion's.
run_json "$length_conversion" tests/verification_length_conversion.adb
for prefix in Compared Added Bound Tested Counted Scaled Qualified \
  Shortened Capped
do
   must_not_prove "$length_conversion" range-check "$prefix'Length" \
     "length conversion"
done
for prefix in Compared Added Bound Tested Counted Scaled Qualified \
  Shortened Capped Brief Few Assigned Passed Cast
do
   if [ "$(grep -F '"kind": "range-check"' "$length_conversion" |
             grep -Fc "\"operation\": \"$prefix'Length\"")" -ne 1 ]
   then
      echo "length conversion: not one range check at $prefix'Length" >&2
      exit 1
   fi
done
for prefix in Universal Summed Other Fixed
do
   if grep -F '"kind": "range-check"' "$length_conversion" |
     grep -F "\"operation\": \"$prefix'Length\"" >/dev/null
   then
      echo "length conversion: a range check at $prefix'Length" >&2
      exit 1
   fi
done
# An array has no more components than its index subtype has values: that
# proves the check where the type has room for them all, in the base range
# of Integer and in the range Short is declared with.
must_prove "$length_conversion" range-check "Brief'Length" \
  abstract-interpretation "length conversion"
must_prove "$length_conversion" range-check "Few'Length" \
  abstract-interpretation "length conversion"

# The limits themselves: the length of each dimension is no more than the
# number of values of its own index subtype, and nothing more is known --
# not of the other dimension, not one component less, not where the bounds
# of the index subtype are not static, and not that an array is not empty.
run_json "$length_limits" tests/verification_length_limits.adb
for claim in "Grid'Length (1) <= 10" "Grid'Length (2) <= 1000" \
  "Bytes'Length <= 256" "Text'Length <= 1000" \
  "Whole (Whole'First .. Whole'Last)'Length <= 1000"
do
   must_prove "$length_limits" assertion "$claim" abstract-interpretation \
     "length limits"
done
for claim in "Grid'Length (2) <= 10" "Grid'Length <= 9" \
  "Octets'Length <= 255" "Items'Length <= 10" "Cells'Length >= 1"
do
   must_not_prove "$length_limits" assertion "$claim" "length limits"
done
if grep -F '"status": "definite-error"' "$length_limits" >/dev/null; then
   echo "length limits: a definite error on a claim that may hold" >&2
   exit 1
fi

# The length check of an array given to a target. GNATprove has one at
# each place the fixture has one, at the same line and column, and proves
# what is proved here.
run_json "$length_check" tests/verification_length_check.adb
must_prove "$length_check" length-check 'Target := (others => 0);' \
  abstract-interpretation "length check"
must_prove "$length_check" length-check '(others => 0)' \
  abstract-interpretation "length check"
must_prove "$length_check" length-check 'and' abstract-interpretation \
  "length check"
for claim in 'Left (1 .. Count) := Right (1 .. Count);' \
  'Right (1 .. Count)' 'Data (2 .. Count) := Data (1 .. Count - 1);' \
  'Data (1 .. Count - 1)' 'Whole := Other;' 'Source' \
  'Buffer (8 * Slot .. 8 * Slot + 7) := Word_Of (Slot);' 'Word_Of (Slot)' \
  'Loose'
do
   must_prove "$length_check" length-check "$claim" external-prover \
     "length check"
done
for claim in 'Front (1 .. Count) := Back (1 .. Count + 1);' \
  'Back (1 .. Count + 1)' 'Head (2 .. Count) := Tail (1 .. Count);' \
  'Tail (1 .. Count)' 'Sink := Origin;' 'Given' 'Long' \
  'Part (1 .. Count)' \
  'Store (8 * Place .. Last) := Word_Of (Place);' \
  'Word_Of (Place)' 'Seed' 'Result_Source' 'Argument' 'Operand' \
  'Bits or More' 'or'
do
   must_not_prove "$length_check" length-check "$claim" "length check"
done
# Never a definite error, and no check where both lengths are static and
# the same or where no constrained subtype receives the value.
if grep -F '"kind": "length-check"' "$length_check" |
  grep -F '"status": "definite-error"' >/dev/null
then
   echo "length check: a definite error" >&2
   exit 1
fi
for claim in 'Kept := Again;' 'Again' 'Again := (others => 0);' \
  'Plenty (1 .. 5)' 'Kept (1 .. 2) := Plenty (3 .. 4);' 'Plenty (3 .. 4)' \
  '(1, 2, 3, 4, 5)' 'Shades := Tints;' 'Tints' '(others => 1)' 'Kept' \
  'Plenty' "(if Plenty'Last = 5 then Again else Kept)"
do
   if grep -F '"kind": "length-check"' "$length_check" |
     grep -F "\"operation\": \"$claim\"" >/dev/null
   then
      echo "length check: an obligation at '$claim'" >&2
      exit 1
   fi
done
# The check of the assignment itself is reported at its ":=".
if ! grep -F '"kind": "length-check"' "$length_check" |
  grep -F '"operation": "Whole := Other;"' |
  grep -F '"line": 53, "column": 13,' >/dev/null
then
   echo "length check: not at the assignment symbol" >&2
   exit 1
fi
# An array has the bounds it was declared with, a slice those of its range
# where it is written: a variable changed since proves nothing.
run_json "$length_check_state" tests/verification_length_check_state.adb
for claim in 'Goal (1 .. Size) := Local;' 'Local' \
  'Into (1 .. Count) := From (1 .. Limit);' 'From (1 .. Limit)' 'Kept'
do
   must_not_prove "$length_check_state" length-check "$claim" \
     "length check"
done

# A constant, a generic formal object of mode "in", an "in" parameter and
# the parameter of a loop or of a quantified expression hold a value
# wherever they are read, within their subtype: a division by one of
# subtype Positive is safe, an index that is one is within an array of its
# range, and neither needs a solver. The parameter of "for I in T range
# L .. H" is within T and within what L and H can be. A named number has
# its value as an operand of a product. An object first named as the
# actual of an inlined call is declared to the solvers like any other.
run_json_pair "$standing_values" tests/verification_standing_values
for operation in Bits Width Step Ceiling; do
   must_prove "$standing_values" division-by-zero "$operation" \
     abstract-interpretation "an object that always holds a value"
done
for operation in Bits Width Ceiling Chosen; do
   if ! grep -F '"kind": "initialization-check"' "$standing_values" |
     grep -F "\"operation\": \"$operation\"" |
     grep -F '"status": "proved-safe"' >/dev/null
   then
      echo "an object that always holds a value: '$operation' is not" \
        "known to hold one" >&2
      exit 1
   fi
done
must_prove "$standing_values" range-check Bits abstract-interpretation \
  "an object that always holds a value"
for operation in Each Done Tail Slot Place Spot Chosen Seen Held Turn; do
   must_prove "$standing_values" index-check "$operation" \
     abstract-interpretation "the parameter of a loop or of a quantifier"
done
must_prove "$standing_values" integer-overflow 'Scale * (Left + Right)' \
  abstract-interpretation "the range of a named number"
must_prove "$standing_values" integer-overflow "Natural'Last - Used" \
  external-prover "the actual of an inlined call"
must_prove "$standing_values" integer-overflow 'Used + Extra' \
  external-prover "the actual of an inlined call"
# Within a subtype is not away from zero; a variable, a formal object of
# mode "in out" and an aliased constant are not known to hold a value.
for operation in Spare Count Shared Level Anchor; do
   must_not_prove "$standing_values" division-by-zero "$operation" \
     "an object that always holds a value"
done
for operation in Shared Level Anchor Mark; do
   must_not_prove "$standing_values" initialization-check "$operation" \
     "an object that always holds a value"
done
must_not_prove "$standing_values" index-check 'Next + 1' \
  "the parameter of a loop or of a quantifier"
must_not_prove "$standing_values" range-check Step \
  "the parameter of a loop or of a quantifier"
must_not_prove "$standing_values" range-check Far \
  "the parameter of a loop or of a quantifier"
for operation in 'Seen = 0' 'Held <= 5' 'Turn <= 6' 'Mark = 5'; do
   must_not_prove "$standing_values" assertion "$operation" \
     "an object that always holds a value"
done
must_not_prove "$standing_values" integer-overflow 'Huge * Both' \
  "the range of a named number"

echo "bounded verification tests passed"
