#!/bin/sh
set -eu

gnatprove=${GNATPROVE:-}
if [ -z "$gnatprove" ]; then
   gnatprove=$(command -v gnatprove || true)
fi
if [ -z "$gnatprove" ] && [ -x "${HOME}/.alire/bin/gnatprove" ]; then
   gnatprove="${HOME}/.alire/bin/gnatprove"
fi

if [ -z "$gnatprove" ]; then
   echo "GNATprove differential tests skipped (gnatprove not found)"
   exit 0
fi

analyzer=${ANALYZER:-./bin/adalang_analyzer}
results=$(mktemp "${TMPDIR:-/tmp}/adalang-gnatprove-diff.XXXXXX")
gnatprove_log=$(mktemp "${TMPDIR:-/tmp}/gnatprove-diff.XXXXXX")
broken_results=$(mktemp "${TMPDIR:-/tmp}/adalang-gnatprove-diff-broken.XXXXXX")
broken_gnatprove_log=$(mktemp "${TMPDIR:-/tmp}/gnatprove-diff-broken.XXXXXX")
trap 'rm -f "$results" "$gnatprove_log" "$broken_results" "$broken_gnatprove_log"' \
  EXIT HUP INT TERM

status=0
"$analyzer" --verify -q --format=json --output="$results" \
  tests/verification_clean.adb \
  tests/verification_loop_clean.adb \
  tests/verification_call_clean.adb \
  tests/verification_vc_clean.adb \
  tests/verification_vc_contracts.adb \
  tests/verification_symbolic_assignment.adb \
  tests/verification_symbolic_branch.adb \
  tests/verification_symbolic_prepost.adb \
  tests/verification_loop_vc_relational.adb \
  tests/verification_array_index_clean.adb \
  tests/verification_many_variables.adb \
  tests/verification_diff_arithmetic.adb \
  tests/verification_diff_conditional.adb \
  tests/verification_diff_modular_call.adb \
  tests/verification_diff_array.adb \
  tests/verification_diff_loop.adb \
  tests/verification_diff_runtime_relational.adb \
  tests/verification_loop_variant_increases.adb \
  tests/verification_loop_branch_clean.adb \
  tests/verification_loop_branch_elsif_clean.adb \
  tests/verification_loop_branch_case_clean.adb \
  tests/verification_loop_branch_ite_precision.adb \
  tests/verification_loop_array_write_clean.adb \
  tests/verification_output_initialization.adb \
  tests/verification_slice_bounds.adb \
  tests/verification_guarded_operand.adb \
  tests/verification_declared_constraint.adb \
  tests/verification_actual_range.adb \
  tests/verification_termination.adb \
  tests/verification_flow_contracts.adb \
  tests/verification_expression_functions.adb || status=$?
if [ "$status" -gt 1 ]; then
   echo "AdaLang Analyzer differential run failed with status $status" >&2
   exit "$status"
fi

grep -F '"status": "proved-safe"' "$results" >/dev/null
if grep -F '"status": "definite-error"' "$results" >/dev/null ||
  grep -F '"status": "unsupported"' "$results" >/dev/null; then
   echo "AdaLang contradicted the clean GNATprove corpus" >&2
   exit 1
fi

# --level=0 alone caps each VC at a 1-second wall-clock timeout, which slow
# CI runners (macOS in particular) can exceed on the 70-term overflow checks
# in verification_many_variables.adb. A step limit is machine-independent;
# the largest VC here needs under 3,000 cvc5 steps, so 100,000 is ample.
if ! "$gnatprove" -P tests/verification_differential.gpr \
  --mode=prove --level=0 --timeout=0 --steps=100000 \
  >"$gnatprove_log" 2>&1; then
   cat "$gnatprove_log"
   exit 1
fi
cat "$gnatprove_log"
grep -F 'Success: all checks proved' "$gnatprove_log" >/dev/null

summary=obj/verification_differential/gnatprove/gnatprove.out
grep -F 'Analyzed 31 units' "$summary" >/dev/null
if grep -F ' skipped;' "$summary" >/dev/null; then
   echo "GNATprove skipped part of the differential corpus" >&2
   exit 1
fi

# The corpus above only shows agreement when both tools see safe code. The
# opposite failure mode -- AdaLang claiming Proved_Safe on code GNATprove
# rejects -- is just as important, so a second corpus of deliberately broken
# fixtures checks that GNATprove also fails to prove each one, and that the
# internal test suite (run_verification.sh) never lets AdaLang mark the
# broken obligation itself Proved_Safe.
status=0
"$analyzer" --verify -q --format=json --output="$broken_results" \
  tests/verification_vc_error.adb \
  tests/verification_loop_vc_broken.adb \
  tests/verification_initialization_error.adb \
  tests/verification_symbolic_call.adb \
  tests/verification_symbolic_join.adb \
  tests/verification_mutation_contracts.adb \
  tests/verification_mutation_runtime.adb \
  tests/verification_mutation_loop_initialization.adb \
  tests/verification_loop_variant_wrong_direction.adb \
  tests/verification_loop_branch_vc_broken.adb \
  tests/verification_loop_branch_elsif_vc_broken.adb \
  tests/verification_loop_branch_case_vc_broken.adb \
  tests/verification_loop_branch_ite_unsafe.adb \
  tests/verification_mutation_output_initialization.adb \
  tests/verification_mutation_slice_bounds.adb \
  tests/verification_mutation_guarded_operand.adb \
  tests/verification_mutation_declared_constraint.adb \
  tests/verification_mutation_deferred_evaluation.adb \
  tests/verification_mutation_actual_range.adb \
  tests/verification_mutation_termination.adb \
  tests/verification_mutation_flow_contracts.adb \
  tests/verification_mutation_expression_functions.adb \
  tests/verification_fp116_declared_operator.ads \
  tests/verification_fp116_declared_operator.adb \
  tests/verification_length_check.adb || status=$?
if [ "$status" -gt 1 ]; then
   echo "AdaLang Analyzer broken-corpus run failed with status $status" >&2
   exit "$status"
fi

"$gnatprove" -P tests/verification_differential_broken.gpr \
  --mode=prove --level=0 >"$broken_gnatprove_log" 2>&1 || true
cat "$broken_gnatprove_log"
if grep -F 'Success: all checks proved' "$broken_gnatprove_log" >/dev/null; then
   echo "GNATprove unexpectedly proved the broken differential corpus;" \
     "a fixture no longer contains a genuine defect" >&2
   exit 1
fi

broken_summary=obj/verification_differential_broken/gnatprove/gnatprove.out
grep -F 'Analyzed 24 units' "$broken_summary" >/dev/null
for unit in verification_vc_error verification_loop_vc_broken \
  verification_initialization_error verification_symbolic_call \
  verification_symbolic_join verification_mutation_contracts \
  verification_mutation_runtime \
  verification_mutation_loop_initialization \
  verification_loop_variant_wrong_direction \
  verification_loop_branch_vc_broken \
  verification_loop_branch_elsif_vc_broken \
  verification_loop_branch_case_vc_broken \
  verification_loop_branch_ite_unsafe \
  verification_mutation_output_initialization \
  verification_mutation_slice_bounds \
  verification_mutation_guarded_operand \
  verification_mutation_declared_constraint \
  verification_mutation_deferred_evaluation \
  verification_mutation_actual_range \
  verification_mutation_termination \
  verification_mutation_flow_contracts \
  verification_mutation_expression_functions \
  verification_fp116_declared_operator \
  verification_length_check; do
   if ! grep -F "in unit $unit," "$broken_summary" >/dev/null; then
      echo "GNATprove did not analyze $unit in the broken corpus" >&2
      exit 1
   fi
   if grep -F "$unit.adb" "$broken_summary" |
     grep -F ' skipped;' >/dev/null
   then
      echo "GNATprove skipped $unit in the broken corpus" >&2
      exit 1
   fi
done
if ! grep -F 'not proved' "$broken_summary" >/dev/null; then
   echo "GNATprove reported no failures in the broken differential corpus" >&2
   exit 1
fi

# Global and Depends aspects are checked by GNATprove's flow analysis, which
# --mode=prove does not run. The two flow-contract fixtures get a run of
# their own: the clean one must have every data and flow dependency proved
# and no check left, the broken one must fail where its comments say.
flow_log=$(mktemp "${TMPDIR:-/tmp}/gnatprove-diff-flow.XXXXXX")
flow_broken_log=$(mktemp "${TMPDIR:-/tmp}/gnatprove-diff-flow-broken.XXXXXX")
trap 'rm -f "$results" "$gnatprove_log" "$broken_results" "$broken_gnatprove_log" "$flow_log" "$flow_broken_log"' \
  EXIT HUP INT TERM

"$gnatprove" -P tests/verification_differential.gpr --mode=flow \
  --report=all --output=oneline -u verification_flow_contracts.adb \
  >"$flow_log" 2>&1 || true
if grep -E 'verification_flow_contracts\.adb:[0-9]+:[0-9]+: (error|high|medium|low):' \
  "$flow_log" >/dev/null
then
   cat "$flow_log"
   echo "GNATprove's flow analysis did not accept the clean flow-contract fixture" >&2
   exit 1
fi
if [ "$(grep -c 'info: data dependencies proved' "$flow_log")" -ne 7 ] ||
  [ "$(grep -c 'info: flow dependencies proved' "$flow_log")" -ne 1 ]
then
   cat "$flow_log"
   echo "GNATprove's flow analysis did not prove every aspect of the clean flow-contract fixture" >&2
   exit 1
fi

"$gnatprove" -P tests/verification_differential_broken.gpr --mode=flow \
  --report=all --output=oneline -u verification_mutation_flow_contracts.adb \
  >"$flow_broken_log" 2>&1 || true
for expected in \
  'must be listed in the Global aspect of "Unlisted_Read"' \
  'must be a global output of "Input_Written"' \
  'Proof_In global "Source" can only be used in assertions' \
  'must be listed in the Global aspect of "Unlisted_By_Call"' \
  '"Maybe" might not be initialized' \
  '"Both.Second" is not initialized' \
  'missing dependency "Value => Factor"'
do
   if ! grep -F "$expected" "$flow_broken_log" >/dev/null; then
      cat "$flow_broken_log"
      echo "GNATprove's flow analysis no longer rejects the broken flow-contract fixture: $expected" >&2
      exit 1
   fi
done

#  Two fixtures are compared check by check. On the one of FP-116 no claim
#  GNATprove fails to prove may be proved here, none it proves may be a
#  definite error, and the precondition of a declared operator is at the
#  operator for both. On the one of the length check GNATprove has its
#  checks at the places of AdaLang's obligations, line and column, and
#  proves what is proved here.
pair_results=$(mktemp "${TMPDIR:-/tmp}/adalang-gnatprove-diff-pair.XXXXXX")
pair_log=$(mktemp "${TMPDIR:-/tmp}/gnatprove-diff-pair.XXXXXX")
trap 'rm -f "$results" "$gnatprove_log" "$broken_results" "$broken_gnatprove_log" "$flow_log" "$flow_broken_log" "$pair_results" "$pair_log"' \
  EXIT HUP INT TERM

status=0
"$analyzer" --verify -q --format=json --output="$pair_results" \
  tests/verification_fp116_declared_operator.ads \
  tests/verification_fp116_declared_operator.adb \
  tests/verification_length_check.adb || status=$?
if [ "$status" -gt 1 ]; then
   echo "AdaLang Analyzer check-by-check run failed with status $status" >&2
   exit "$status"
fi
"$gnatprove" -P tests/verification_differential_broken.gpr --mode=prove \
  --level=1 --report=all --output=oneline \
  -u verification_fp116_declared_operator.adb >"$pair_log" 2>&1 || true
"$gnatprove" -P tests/verification_differential_broken.gpr --mode=prove \
  --level=1 --report=all --output=oneline \
  -u verification_length_check.adb >>"$pair_log" 2>&1 || true

python3 - "$pair_results" "$pair_log" <<'PYTHON'
import collections
import json
import re
import sys

report = json.load(open(sys.argv[1]))
log = open(sys.argv[2]).read().split("\n")


def fail(message):
    print("gnatprove differential: " + message, file=sys.stderr)
    sys.exit(1)


#  (file, line, column, proved, text) of each check of GNATprove's.
checks = []
for line in log:
    found = re.match(
        r"(\S+\.ad[bs]):(\d+):(\d+): (info|low|medium|high): (.*)", line)
    if found:
        text = found.group(5)
        checks.append((found.group(1), int(found.group(2)),
                       int(found.group(3)),
                       found.group(4) == "info" and " proved" in text, text))


def mine(unit, kind):
    return [item for item in report["proofObligations"]
            if item["file"].endswith(unit) and item["kind"] == kind]


operators = "verification_fp116_declared_operator.adb"
asserted = [check for check in checks
            if check[0] == operators and check[4].startswith("assertion")]
if len(asserted) != 25:
    fail(f"FP-116: GNATprove reports {len(asserted)} assertions, not 25")
refused = 0
for _, line, _, proved, _ in asserted:
    here = [item for item in mine(operators, "assertion")
            if item["line"] == line]
    if len(here) != 1:
        fail(f"FP-116: {len(here)} assertion obligations at line {line}")
    if not proved:
        refused += 1
        if here[0]["status"] == "proved-safe":
            fail(f"FP-116: line {line} is proved, and GNATprove refuses it")
    elif here[0]["status"] == "definite-error":
        fail(f"FP-116: line {line} is an error, and GNATprove proves it")
if refused != 21:
    fail(f"FP-116: GNATprove refuses {refused} assertions, not 21")
theirs = sorted((check[1], check[2]) for check in checks
                if check[0] == operators
                and check[4].startswith("precondition"))
ours = sorted((item["line"], item["column"])
              for item in mine(operators, "precondition"))
if len(theirs) != 2 or theirs != ours:
    fail(f"FP-116: preconditions at {theirs} for GNATprove, {ours} here")

lengths = "verification_length_check.adb"
theirs = collections.Counter(
    (check[1], check[2]) for check in checks
    if check[0] == lengths and check[4].startswith("length check"))
ours = collections.Counter(
    (item["line"], item["column"]) for item in mine(lengths, "length-check"))
if not theirs or theirs != ours:
    fail("length check: GNATprove and AdaLang differ at "
         + str(sorted((theirs - ours) + (ours - theirs))))
proved_there = collections.Counter(
    (check[1], check[2]) for check in checks
    if check[0] == lengths and check[4].startswith("length check")
    and check[3])
proved_here = collections.Counter(
    (item["line"], item["column"]) for item in mine(lengths, "length-check")
    if item["status"] == "proved-safe")
if proved_here - proved_there:
    fail("length check: proved here and not by GNATprove at "
         + str(sorted(proved_here - proved_there)))
if not proved_here:
    fail("length check: nothing is proved")
print(f"check by check: {len(asserted)} assertions of FP-116, "
      f"{sum(theirs.values())} length checks at the same places, "
      f"{sum(proved_here.values())} of them proved by both")
PYTHON

echo "GNATprove differential tests passed"
