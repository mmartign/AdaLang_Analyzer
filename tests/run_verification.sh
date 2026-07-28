#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
clean=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-clean.XXXXXX")
loop=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-loop.XXXXXX")
unsupported=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-unsupported.XXXXXX")
call=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-call.XXXXXX")
many=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-many.XXXXXX")
initialization=$(mktemp "${TMPDIR:-/tmp}/adalang-verify-init.XXXXXX")
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
trap 'rm -f "$clean" "$loop" "$unsupported" "$call" "$many" "$initialization" "$exception_model" "$vc_clean" "$vc_error" "$vc_unsupported" "$vc_unavailable" "$vc_guarded" "$vc_contracts" "$symbolic_assignment" "$symbolic_branch" "$symbolic_join" "$symbolic_call" "$symbolic_prepost" "$symbolic_loop" "$loop_vc_relational" "$loop_vc_broken"' EXIT HUP INT TERM

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

run_json "$many" tests/verification_many_variables.adb
grep -F '"kind": "assertion", "status": "proved-safe"' "$many" >/dev/null

run_json "$initialization" tests/verification_initialization_error.adb
grep -F '"kind": "initialization-check", "status": "definite-error"' \
  "$initialization" >/dev/null

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

echo "bounded verification tests passed"
