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
#   4. on the fixtures, a step budget gives the statuses the time limit gives;
#   5. solvers beside the executable, as a release archive holds them, come
#      before those on PATH.

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

#  The wrappers that log the command lines are shell scripts, which a
#  Windows program cannot start: there the solvers run as they are, and
#  the command lines, built the same way on every host, are checked on
#  the others. (The block is not indented: it holds here-documents and
#  multi-line expected values.)
case $(uname -s) in
   MINGW* | MSYS* | CYGWIN*) wrap_solvers=no ;;
   *) wrap_solvers=yes ;;
esac

if [ "$wrap_solvers" = yes ]; then
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
else
echo "solver limits: command lines not checked (Windows does not start a shell script as a solver)"
"$analyzer" --no-config --verify --format=json --solver-steps=3000 \
  "$generic_spec" "$generic_body" >"$work/calls.json" 2>/dev/null || true
fi

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

#  --- 5. solvers beside the analyzer ----------------------------------------
#
#  A release archive puts cvc5 and z3 beside the executable. They are used
#  before those on PATH, however the analyzer was started (by its path,
#  through a symbolic link, or by name from PATH); ADALANG_CVC5 and
#  ADALANG_Z3 still come first. (A dependency appends the directory the
#  analyzer was started from to its PATH: before, solvers there were found
#  only when PATH held none, and not through a link.) The wrappers that
#  record which solver ran are shell scripts, which Windows does not start.

if [ "$wrap_solvers" = yes ]; then
mkdir "$work/bundle" "$work/link" "$work/onpath"
ln "$analyzer" "$work/bundle/adalang_analyzer" 2>/dev/null ||
  cp "$analyzer" "$work/bundle/adalang_analyzer"
ln -s "$work/bundle/adalang_analyzer" "$work/link/adalang_analyzer"
for name in z3 cvc5; do
   eval "real=\$$name"
   for place in bundle onpath; do
      cat >"$work/$place/$name" <<EOF
#!/bin/sh
echo "$place $name" >>"$work/which.log"
exec "$real" "\$@"
EOF
      chmod +x "$work/$place/$name"
   done
done

#  The solvers that run when the analyzer is started as $1 with PATH $2.
used() {
   rm -f "$work/which.log"
   env -u ADALANG_CVC5 -u ADALANG_Z3 PATH="$2" \
     "$1" --no-config --verify --format=json "$fixture" \
     >/dev/null 2>&1 || true
   [ -f "$work/which.log" ] && sort -u "$work/which.log"
   return 0
}
bundled="bundle cvc5
bundle z3"
[ "$(used "$work/bundle/adalang_analyzer" "$work/onpath:$PATH")" = "$bundled" ] ||
  fail "the solvers beside the analyzer did not come before those on PATH"
[ "$(used "$work/link/adalang_analyzer" "$work/onpath:$PATH")" = "$bundled" ] ||
  fail "the solvers beside the analyzer were not used through a link"
[ "$(used adalang_analyzer "$work/link:$work/onpath:$PATH")" = "$bundled" ] ||
  fail "the solvers beside the analyzer were not used when it was found on PATH"

rm -f "$work/which.log"
ADALANG_CVC5="$cvc5" ADALANG_Z3="$z3" PATH="$work/onpath:$PATH" \
  "$work/bundle/adalang_analyzer" --no-config --verify --format=json \
  "$fixture" >/dev/null 2>&1 || true
[ ! -f "$work/which.log" ] ||
  fail "the solvers beside the analyzer came before ADALANG_CVC5/ADALANG_Z3"
fi

echo "solver limit tests passed"
