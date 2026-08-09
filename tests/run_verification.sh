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
symbolic_assignment=$(mktemp "${TMPDIR:-/tmp}/adalang-symbolic-assignment.XXXXXX")
symbolic_branch=$(mktemp "${TMPDIR:-/tmp}/adalang-symbolic-branch.XXXXXX")
symbolic_join=$(mktemp "${TMPDIR:-/tmp}/adalang-symbolic-join.XXXXXX")
symbolic_call=$(mktemp "${TMPDIR:-/tmp}/adalang-symbolic-call.XXXXXX")
symbolic_prepost=$(mktemp "${TMPDIR:-/tmp}/adalang-symbolic-prepost.XXXXXX")
symbolic_loop=$(mktemp "${TMPDIR:-/tmp}/adalang-symbolic-loop.XXXXXX")
loop_vc_relational=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-vc-relational.XXXXXX")
loop_vc_broken=$(mktemp "${TMPDIR:-/tmp}/adalang-loop-vc-broken.XXXXXX")
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
trap 'rm -f "$clean" "$loop" "$unsupported" "$call" "$many" "$initialization" "$initialization_defaults" "$initialization_rename" "$exception_model" "$vc_clean" "$vc_error" "$vc_unsupported" "$vc_unavailable" "$vc_guarded" "$vc_contracts" "$symbolic_assignment" "$symbolic_branch" "$symbolic_join" "$symbolic_call" "$symbolic_prepost" "$symbolic_loop" "$loop_vc_relational" "$loop_vc_broken" "$out_forwarding" "$interprocedural_effects" "$interprocedural_ordinary" "$loop_stale_init" "$loop_stale_range" "$loop_stale_range_obligation" "$loop_stale_index" "$loop_stale_division" "$loop_stale_overflow" "$loop_stale_assert" "$loop_stale_precondition" "$global_aspect_clean" "$global_aspect_guard" "$initialization_pragma_unreferenced" "$own_name_qualifier"' EXIT HUP INT TERM

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
grep -F '"kind": "loop-variant"' "$loop" >/dev/null

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
