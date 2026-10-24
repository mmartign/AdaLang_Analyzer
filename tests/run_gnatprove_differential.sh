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
  tests/verification_length_check.adb \
  tests/verification_standing_values.ads \
  tests/verification_standing_values.adb || status=$?
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
grep -F 'Analyzed 30 units' "$broken_summary" >/dev/null
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
  verification_length_check \
  verification_standing_values \
  verification_flow_dependencies \
  verification_predicate_checks \
  verification_old \
  verification_declared_bound_division \
  verification_loop_entry_widening; do
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

#  Three fixtures are compared check by check. On the one of FP-116 no
#  claim GNATprove fails to prove may be proved here, none it proves may be
#  a definite error, and the precondition of a declared operator is at the
#  operator for both. On the one of the length check GNATprove has its
#  checks at the places of AdaLang's obligations, line and column, and
#  proves what is proved here. On the one of the objects that always hold
#  a value, no check GNATprove fails to prove is proved here, nothing it
#  proves is a definite error, and GNATprove proves divisions and index
#  checks that are proved here.
pair_results=$(mktemp "${TMPDIR:-/tmp}/adalang-gnatprove-diff-pair.XXXXXX")
pair_log=$(mktemp "${TMPDIR:-/tmp}/gnatprove-diff-pair.XXXXXX")
trap 'rm -f "$results" "$gnatprove_log" "$broken_results" "$broken_gnatprove_log" "$flow_log" "$flow_broken_log" "$pair_results" "$pair_log"' \
  EXIT HUP INT TERM

status=0
"$analyzer" --verify -q --format=json --output="$pair_results" \
  tests/verification_fp116_declared_operator.ads \
  tests/verification_fp116_declared_operator.adb \
  tests/verification_length_check.adb \
  tests/verification_standing_values.ads \
  tests/verification_standing_values.adb || status=$?
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
"$gnatprove" -P tests/verification_differential_broken.gpr --mode=prove \
  --level=1 --report=all --output=oneline \
  -u verification_standing_values.adb >>"$pair_log" 2>&1 || true

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

#  The kind of AdaLang's obligation for each check of GNATprove's on the
#  fixture of the objects that always hold a value.
standing = "verification_standing_values.adb"
kinds = (("divide by zero", "division-by-zero"),
         ("division check", "division-by-zero"),
         ("array index check", "index-check"),
         ("index check", "index-check"),
         ("range check", "range-check"),
         ("overflow check", "integer-overflow"),
         ("assertion", "assertion"))


def kind_of(text):
    for prefix, kind in kinds:
        if text.startswith(prefix):
            return kind
    return None


refused_there = 0
agreed = collections.Counter()
for name, line, column, proved, text in checks:
    kind = kind_of(text)
    if name != standing or kind is None:
        continue
    #  The obligation at GNATprove's own column where there is one, and
    #  otherwise every one of the kind on the line: the two tools do not
    #  always report a check at the same token of an expression.
    here = [item for item in mine(standing, kind) if item["line"] == line]
    exact = [item for item in here if item["column"] == column]
    if exact:
        here = exact
    if not proved:
        refused_there += 1
        if not here:
            fail(f"standing values: no {kind} obligation at line {line}")
        for item in here:
            if item["status"] == "proved-safe":
                fail(f"standing values: {kind} at line {line} is proved, "
                     "and GNATprove refuses it")
    else:
        for item in here:
            if item["status"] == "definite-error":
                fail(f"standing values: {kind} at line {line} is an error, "
                     "and GNATprove proves it")
            if item["status"] == "proved-safe":
                agreed[kind] += 1
if refused_there != 8:
    fail(f"standing values: GNATprove refuses {refused_there} checks, not 8")
if agreed["division-by-zero"] < 4 or agreed["index-check"] < 2:
    fail("standing values: proved by both: " + str(dict(agreed)))
print(f"check by check: {len(asserted)} assertions of FP-116, "
      f"{sum(theirs.values())} length checks at the same places, "
      f"{sum(proved_here.values())} of them proved by both; "
      f"{refused_there} checks of the standing values refused by both, "
      f"{sum(agreed.values())} proved by both")
PYTHON

#  The flow-dependencies fixture, aspect by aspect: each Depends aspect of
#  its spec is proved here exactly when GNATprove's flow analysis proves it,
#  but for Bad_Formal, whose generic one instantiation gives a procedure
#  that writes a global: GNATprove reports the global missing from the
#  Global aspect and proves the Depends aspect in that instance; here the
#  effects of the formal are not known and neither aspect is proved.
deps_results=$(mktemp "${TMPDIR:-/tmp}/adalang-gnatprove-diff-deps.XXXXXX")
deps_log=$(mktemp "${TMPDIR:-/tmp}/gnatprove-diff-deps.XXXXXX")
trap 'rm -f "$results" "$gnatprove_log" "$broken_results" "$broken_gnatprove_log" "$flow_log" "$flow_broken_log" "$pair_results" "$pair_log" "$deps_results" "$deps_log"' \
  EXIT HUP INT TERM

status=0
"$analyzer" --verify -q --format=json --output="$deps_results" \
  tests/verification_flow_dependencies.ads \
  tests/verification_flow_dependencies.adb || status=$?
if [ "$status" -gt 1 ]; then
   echo "AdaLang Analyzer flow-dependencies run failed with status $status" >&2
   exit "$status"
fi
"$gnatprove" -P tests/verification_differential_broken.gpr --mode=flow \
  --report=all --output=oneline -u verification_flow_dependencies.adb \
  >"$deps_log" 2>&1 || true

python3 - "$deps_results" "$deps_log" <<'PYTHON'
import json
import re
import sys

report = json.load(open(sys.argv[1]))
log = open(sys.argv[2]).read().split("\n")
spec = "verification_flow_dependencies.ads"


def fail(message):
    print("gnatprove differential: " + message, file=sys.stderr)
    sys.exit(1)


#  The lines of the spec where GNATprove proves a Depends aspect, that of a
#  generic in its instance, and those where it reports a dependency it
#  finds wrong.
proved, refused = set(), set()
for line in log:
    found = re.match(
        r"(\S+\.ad[bs]):(\d+):\d+: (info|low|medium|high): (.*)", line)
    if not found or not found.group(1).endswith(spec):
        continue
    text, where = found.group(4), int(found.group(2))
    if text.startswith("flow dependencies proved"):
        proved.add(where)
    elif "dependency" in text:
        refused.add(where)

ours = {}
for item in report["proofObligations"]:
    if item["kind"] == "flow-dependencies" and item["file"].endswith(spec):
        ours[item["line"]] = (item["operation"],
                              item["status"] == "proved-safe")
if len(ours) != 44:
    fail(f"flow dependencies: {len(ours)} obligations in the spec, not 44")
agreed = 0
for line, (operation, here) in sorted(ours.items()):
    there = line in proved and line not in refused
    if operation == "Depends of Bad_Formal":
        if here:
            fail("flow dependencies: Bad_Formal is proved")
        continue
    if here != there:
        fail(f"flow dependencies: {operation} at line {line} is "
             f"{'proved' if here else 'not proved'} here, "
             f"{'proved' if there else 'not proved'} by GNATprove")
    agreed += 1
print(f"flow dependencies: {agreed} Depends aspects, the same verdict as "
      "GNATprove's flow analysis")
PYTHON

#  The predicate-check and 'Old fixtures, check by check: each predicate
#  check, postcondition and assertion proved here is proved by GNATprove at
#  the same line, where it reports no failure of the same kind. A level
#  above 0 proves the checks of the Ok_* subprograms there.
pairs_results=$(mktemp "${TMPDIR:-/tmp}/adalang-gnatprove-diff-pairs.XXXXXX")
pairs_log=$(mktemp "${TMPDIR:-/tmp}/gnatprove-diff-pairs.XXXXXX")
trap 'rm -f "$results" "$gnatprove_log" "$broken_results" "$broken_gnatprove_log" "$flow_log" "$flow_broken_log" "$pair_results" "$pair_log" "$deps_results" "$deps_log" "$pairs_results" "$pairs_log"' \
  EXIT HUP INT TERM

status=0
"$analyzer" --verify -q --format=json --output="$pairs_results" \
  tests/verification_predicate_checks.ads \
  tests/verification_predicate_checks.adb \
  tests/verification_old.ads tests/verification_old.adb || status=$?
if [ "$status" -gt 1 ]; then
   echo "AdaLang Analyzer predicate and 'Old run failed with status $status" >&2
   exit "$status"
fi
"$gnatprove" -P tests/verification_differential_broken.gpr --mode=prove \
  --level=2 --report=all --output=oneline \
  -u verification_predicate_checks.adb verification_old.adb \
  >"$pairs_log" 2>&1 || true

python3 - "$pairs_results" "$pairs_log" <<'PYTHON'
import json
import re
import sys

report = json.load(open(sys.argv[1]))
log = open(sys.argv[2]).read().split("\n")
kinds = {"predicate-check": "predicate check",
         "postcondition": "postcondition",
         "assertion": "assertion"}
units = ("verification_predicate_checks.ad", "verification_old.ad")


def fail(message):
    print("gnatprove differential: " + message, file=sys.stderr)
    sys.exit(1)


proved, refused = set(), set()
for line in log:
    found = re.match(
        r"(\S+\.ad[bs]):(\d+):\d+: (info|low|medium|high): (.*)", line)
    if not found or not found.group(1).startswith(units):
        continue
    place = (found.group(1), int(found.group(2)))
    for text in kinds.values():
        if found.group(4).startswith(text):
            if found.group(3) == "info":
                proved.add(place + (text,))
            else:
                refused.add(place + (text,))

agreed = 0
for item in report["proofObligations"]:
    name = item["file"].split("/")[-1]
    if item["kind"] not in kinds or not name.startswith(units):
        continue
    if item["status"] != "proved-safe":
        continue
    place = (name, item["line"], kinds[item["kind"]])
    if place not in proved or place in refused:
        fail(f"{item['kind']} {item['operation']!r} at {name}:"
             f"{item['line']} is proved here, not by GNATprove")
    agreed += 1
if agreed < 20:
    fail(f"predicate checks and 'Old: only {agreed} checks proved")
print(f"predicate checks and 'Old: {agreed} checks proved here, each "
      "proved by GNATprove")
PYTHON

#  The overflow checks of the declared-bound and loop-entry fixtures, by
#  line and expression: none proved here is one GNATprove finds might fail,
#  and it finds the three of the Bad_* subprograms might, which are not
#  proved here. Where the compiler sees an operation cannot overflow it
#  places no check, and GNATprove reports none.
bounds_results=$(mktemp "${TMPDIR:-/tmp}/adalang-gnatprove-diff-bounds.XXXXXX")
bounds_log=$(mktemp "${TMPDIR:-/tmp}/gnatprove-diff-bounds.XXXXXX")
trap 'rm -f "$results" "$gnatprove_log" "$broken_results" "$broken_gnatprove_log" "$flow_log" "$flow_broken_log" "$pair_results" "$pair_log" "$deps_results" "$deps_log" "$pairs_results" "$pairs_log" "$bounds_results" "$bounds_log"' \
  EXIT HUP INT TERM

status=0
"$analyzer" --verify -q --format=json --output="$bounds_results" \
  tests/verification_declared_bound_division.ads \
  tests/verification_declared_bound_division.adb \
  tests/verification_loop_entry_widening.adb || status=$?
if [ "$status" -gt 1 ]; then
   echo "AdaLang Analyzer declared-bound run failed with status $status" >&2
   exit "$status"
fi
"$gnatprove" -P tests/verification_differential_broken.gpr --mode=prove \
  --level=2 --report=all --output=oneline \
  -u verification_declared_bound_division.adb \
  verification_loop_entry_widening.adb >"$bounds_log" 2>&1 || true

python3 - "$bounds_results" "$bounds_log" <<'PYTHON'
import json
import re
import sys

report = json.load(open(sys.argv[1]))
log = open(sys.argv[2]).read().split("\n")
units = ("verification_declared_bound_division.ad",
         "verification_loop_entry_widening.ad")


def fail(message):
    print("gnatprove differential: " + message, file=sys.stderr)
    sys.exit(1)


refused = set()
for line in log:
    found = re.match(
        r"(\S+\.ad[bs]):(\d+):\d+: (low|medium|high): overflow check "
        r"might fail, cannot prove (?:upper|lower) bound for (.*?) \[", line)
    if found and found.group(1).startswith(units):
        refused.add((found.group(1), int(found.group(2)), found.group(4)))

proved, unproved = set(), set()
for item in report["proofObligations"]:
    name = item["file"].split("/")[-1]
    if item["kind"] != "integer-overflow" or not name.startswith(units):
        continue
    place = (name, item["line"], " ".join(item["operation"].split()))
    (proved if item["status"] == "proved-safe" else unproved).add(place)

for place in sorted(proved & refused):
    fail(f"overflow check {place[2]!r} at {place[0]}:{place[1]} is proved "
         "here, GNATprove finds it might fail")
if len(refused) != 3 or not refused <= unproved:
    fail(f"declared bounds: GNATprove refuses {sorted(refused)}, not the "
         "three overflow checks of the Bad_* subprograms")
if len(proved) < 10:
    fail(f"declared bounds: only {len(proved)} overflow checks proved")
print(f"declared bounds: {len(proved)} overflow checks proved here, none "
      "refused by GNATprove, which refuses the 3 left unproved")
PYTHON

echo "GNATprove differential tests passed"
