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
loop_branch_elsif=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-branch-elsif.XXXXXX")
loop_array_write=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-array-write.XXXXXX")
loop_record_write=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-record-write.XXXXXX")
loop_length_symbolic=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-length-symbolic.XXXXXX")
length_attribute_unsound=$(mktemp "${TMPDIR:-/tmp}/adalang-length-attribute-unsound.XXXXXX")
loop_variant_dynamic_bound=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-variant-dynamic-bound.XXXXXX")
loop_variant_increases=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-variant-increases.XXXXXX")
loop_variant_wrong=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-variant-wrong.XXXXXX")
loop_variant_unsupported=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-variant-unsupported.XXXXXX")
loop_variant_leading_order=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-variant-leading-order.XXXXXX")
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
global_aspect_guard=$(mktemp "${TMPDIR:-/tmp}/adalang-global-aspect-guard.XXXXXX")
own_name_qualifier=$(mktemp "${TMPDIR:-/tmp}/adalang-own-name-qualifier.XXXXXX")
cross_project=$(mktemp "${TMPDIR:-/tmp}/adalang-cross-project.XXXXXX")
cross_project_stderr=$(mktemp "${TMPDIR:-/tmp}/adalang-cross-project-stderr.XXXXXX")
trap 'rm -f "$clean" "$loop" "$unsupported" "$call" "$many" "$initialization" "$initialization_defaults" "$initialization_rename" "$exception_model" "$vc_clean" "$vc_error" "$vc_unsupported" "$vc_unavailable" "$vc_guarded" "$vc_contracts" "$vc_division" "$vc_division_refuted" "$vc_division_zero_possible" "$vc_call_inlined" "$vc_unsupported_provenance" "$vc_contract_loop_provenance" "$vc_runtime_solver" "$vc_call_statement_body" "$vc_conversion" "$vc_conversion_modular" "$vc_quantified" "$vc_quantified_outside" "$vc_enum_assignment" "$vc_enum_error" "$vc_unsupported_sort" "$vc_derived_overflow_base" "$symbolic_assignment" "$symbolic_branch" "$symbolic_join" "$symbolic_call" "$symbolic_prepost" "$symbolic_loop" "$loop_vc_relational" "$loop_vc_broken" "$loop_branch_clean" "$loop_branch_broken" "$loop_branch_elsif" "$loop_array_write" "$loop_record_write" "$loop_length_symbolic" "$length_attribute_unsound" "$loop_variant_dynamic_bound" "$loop_variant_increases" "$loop_variant_wrong" "$loop_variant_unsupported" "$loop_variant_leading_order" "$out_forwarding" "$interprocedural_effects" "$interprocedural_ordinary" "$loop_stale_init" "$loop_stale_range" "$loop_stale_range_obligation" "$loop_stale_index" "$loop_stale_division" "$loop_stale_overflow" "$loop_stale_assert" "$loop_stale_precondition" "$global_aspect_clean" "$global_aspect_guard" "$initialization_pragma_unreferenced" "$own_name_qualifier"' EXIT HUP INT TERM

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

#  elsif/case chains remain outside the supported subset -- only a single
#  non-nested if/else reconverging on the loop back edge is handled. This
#  documents that boundary rather than silently regressing it.
run_json "$loop_branch_elsif" \
  tests/verification_loop_branch_elsif_unsupported.adb
grep -F '"kind": "loop-invariant-preservation", "status": "unproved"' \
  "$loop_branch_elsif" >/dev/null
grep -F '"kind": "loop-variant", "status": "unproved"' \
  "$loop_branch_elsif" >/dev/null

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

#  A Loop_Invariant is only ever discharged when every loop-body statement
#  before it is itself a leading loop-invariant/loop-variant pragma (see
#  Is_Leading_Loop_Proof_Pragma in flow_interp.adb). This fixture is
#  verification_loop_variant_increases.adb with its two pragmas swapped --
#  Loop_Variant first, Loop_Invariant second, the dominant real-world style
#  (e.g. every one of the EliAvila10/project_bias corpus's 26 loops; see
#  benchmarks/project_bias/RESULTS_2026-08-13.md). Ada/SPARK attaches no
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

echo "bounded verification tests passed"
