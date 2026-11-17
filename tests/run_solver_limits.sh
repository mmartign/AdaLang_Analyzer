#!/bin/sh
set -eu

#  --solver-steps and --solver-timeout: what each solver is given per query.
#
#  It checks:
#   1. invalid values are refused;
#   2. the report states the limit in force (analysisConfiguration.solverLimit)
#      and, with --verify, the solver runs and those the time limit stopped
#      (solverStatistics);
#   3. the solvers get exactly the command lines the limit calls for: by
#      default those of releases before the step limit, with steps a resource
#      limit (Z3 rlimit, CVC5 --rlimit-per) and the safety time stop, and a
#      quarter of either in the passes over the instances of a generic unit;
#   4. on the fixtures, a step budget gives the statuses the time limit gives.

analyzer=${ANALYZER:-./bin/adalang_analyzer}
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-solver-limits.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

fail() { echo "solver limits: $*" >&2; exit 1; }

fixture=tests/verification_vc_contracts.adb
generic_spec=tests/verification_mutation_formal_contracts.ads
generic_body=tests/verification_mutation_formal_contracts.adb

#  --- 1. invalid values ----------------------------------------------------

for option in --solver-steps=0 --solver-steps=abc --solver-steps=-3 \
              --solver-steps=999999999999 --solver-timeout=0 \
              --solver-timeout=x
do
   if "$analyzer" --no-config --verify "$option" "$fixture" >"$work/out" 2>&1
   then
      fail "$option was accepted"
   fi
   grep -F 'invalid solver' "$work/out" >/dev/null ||
     fail "$option: no 'invalid solver' message"
done

#  --- 2. what the report says ------------------------------------------------

json_field() {
   python3 -c 'import json, sys
r = json.load(open(sys.argv[1]))
v = r
for key in sys.argv[2].split("."):
    v = v.get(key) if isinstance(v, dict) else None
print(json.dumps(v))' "$1" "$2"
}

expect_limit() {
   wanted=$1
   shift
   "$analyzer" --no-config --verify --format=json "$@" "$fixture" \
     >"$work/report.json" 2>/dev/null || true
   got=$(json_field "$work/report.json" analysisConfiguration.solverLimit)
   [ "$got" = "\"$wanted\"" ] || fail "$*: solverLimit $got, expected \"$wanted\""
}

expect_limit "time 2000 ms"
expect_limit "time 5000 ms" --solver-timeout=5000
expect_limit "steps 3000, time 6000 ms" --solver-steps=3000
expect_limit "steps 3000, time 4000 ms" --solver-steps=3000 --solver-timeout=4000
expect_limit "steps 3000, time 4000 ms" --solver-timeout=4000 --solver-steps=3000

"$analyzer" --no-config --format=json -checks=-*,No_Goto tests/bug_findings.adb \
  >"$work/plain.json" 2>/dev/null || true
[ "$(json_field "$work/plain.json" solverStatistics)" = "null" ] ||
  fail "solverStatistics in a report without --verify"

#  --- 3. the solvers' command lines -----------------------------------------

solver() {
   name=$1
   variable=$2
   eval "given=\${$variable:-}"
   if [ -n "$given" ]; then
      echo "$given"
   elif command -v "$name" >/dev/null 2>&1; then
      command -v "$name"
   elif [ -x "$HOME/.alire/libexec/spark/bin/$name" ]; then
      echo "$HOME/.alire/libexec/spark/bin/$name"
   fi
}
z3=$(solver z3 ADALANG_Z3)
cvc5=$(solver cvc5 ADALANG_CVC5)
if [ -z "$z3" ] || [ -z "$cvc5" ]; then
   echo "solver limits: command-line and status checks skipped (Z3 or CVC5 not found)"
   echo "solver limit tests passed"
   exit 0
fi

for name in z3 cvc5; do
   eval "real=\$$name"
   cat >"$work/$name" <<EOF
#!/bin/sh
for a; do last=\$a; done
args=\$(printf '%s ' "\$@" | sed "s#\$last #FILE#")
echo "$name \$args" >>"$work/calls.log"
exec "$real" "\$@"
EOF
   chmod +x "$work/$name"
done

calls() {
   rm -f "$work/calls.log"
   ADALANG_Z3="$work/z3" ADALANG_CVC5="$work/cvc5" \
     "$analyzer" --no-config --verify --format=json "$@" \
     >"$work/calls.json" 2>/dev/null || true
   sort -u "$work/calls.log"
}

expect_calls() {
   wanted=$1
   shift
   calls "$@" >"$work/got"
   printf '%s\n' "$wanted" | sort -u >"$work/wanted"
   if ! cmp -s "$work/wanted" "$work/got"; then
      echo "solver command lines for: $*" >&2
      diff -u "$work/wanted" "$work/got" >&2 || true
      exit 1
   fi
}

expect_calls "cvc5 --lang=smt2 --tlimit=2000 FILE
z3 -smt2 -t:2000 FILE" "$fixture"

expect_calls "cvc5 --lang=smt2 --tlimit=6000 --rlimit-per=1200000 FILE
z3 -smt2 -t:6000 rlimit=21000000 FILE" --solver-steps=3000 "$fixture"

expect_calls "cvc5 --lang=smt2 --tlimit=2000 FILE
cvc5 --lang=smt2 --tlimit=500 FILE
z3 -smt2 -t:2000 FILE" "$generic_spec" "$generic_body"

expect_calls "cvc5 --lang=smt2 --tlimit=6000 --rlimit-per=1200000 FILE
cvc5 --lang=smt2 --tlimit=1500 --rlimit-per=300000 FILE
z3 -smt2 -t:6000 rlimit=21000000 FILE" --solver-steps=3000 \
  "$generic_spec" "$generic_body"

runs=$(json_field "$work/calls.json" solverStatistics.runs)
[ "$runs" -gt 0 ] || fail "solverStatistics.runs is $runs"
[ "$(json_field "$work/calls.json" solverStatistics.stoppedByTime)" = 0 ] ||
  fail "a fixture query was stopped by time"

#  --- 4. same statuses -------------------------------------------------------

statuses() {
   python3 -c 'import json, sys
r = json.load(open(sys.argv[1]))
for o in r["proofObligations"]:
    print(o["kind"], o["file"], o["line"], o["column"], o["status"], o["method"])' "$1" | sort
}

for body in tests/verification_vc_contracts.adb \
            tests/verification_mutation_formal_contracts.adb \
            tests/verification_proof_paths_abstract.adb
do
   spec=${body%.adb}.ads
   [ -f "$spec" ] || spec=
   "$analyzer" --no-config --verify --format=json ${spec:+"$spec"} "$body" \
     >"$work/time.json" 2>/dev/null || true
   "$analyzer" --no-config --verify --format=json --solver-steps=3000 \
     ${spec:+"$spec"} "$body" >"$work/steps.json" 2>/dev/null || true
   statuses "$work/time.json" >"$work/time.txt"
   statuses "$work/steps.json" >"$work/steps.txt"
   if ! cmp -s "$work/time.txt" "$work/steps.txt"; then
      echo "solver limits: $body: steps and time give different statuses" >&2
      diff -u "$work/time.txt" "$work/steps.txt" >&2 || true
      exit 1
   fi
done

echo "solver limit tests passed"
