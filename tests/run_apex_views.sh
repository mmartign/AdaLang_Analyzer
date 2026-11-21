#!/bin/sh
set -eu

#  Sources of Rational Apex views, analyzed through GPR projects that give
#  the Apex file names (docs/src/configuration.md, "Rational Apex and ApexAda
#  sources"). tests/apex_views holds two subsystems with one working view
#  each: app.ss/main.wrk imports util.ss/main.wrk, whose units are named
#  unit.1.ada (specification) and unit.2.ada (body), with a child unit
#  (counters.limits.1.ada) and a subunit (counters.reset.2.ada). The GPR
#  projects in tests/apex_views/projects stand for the views: one project a
#  view, a "with" for each view it imports, and the Apex naming scheme
#  shared from apex_naming.gpr.

analyzer=${ANALYZER:-./bin/adalang_analyzer}
views=tests/apex_views
projects=$views/projects
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-apex.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

#  Known_Range_Check_Failure finds the assignment in main.2.ada only when
#  the range of Counters.Counter (counters.1.ada) and the value of
#  Counters.Limits.Top (counters.limits.1.ada) resolve. Long_Line finds a
#  line of counters.1.ada: when it is analyzed, and not when it is only
#  looked up.
checks='Known_Range_Check_Failure,Long_Line'
in_app="$views/app.ss/main.wrk/main.2.ada 9 13 Known_Range_Check_Failure"
in_util="$views/util.ss/main.wrk/counters.1.ada 6 121 Long_Line"

#  The findings of a JSON report: file, line, column and check, one a line.
findings() {
   sed -n 's/.*"ruleId": "\([^"]*\)".*"file": "\([^"]*\)", "line": \([0-9]*\), "column": \([0-9]*\).*/\2 \3 \4 \1/p' \
      "$1"
}

#  Runs the analyzer on the rest of the arguments, which must find
#  violations, writing $work/$1.json and $work/$1.log.
analyze() {
   name=$1
   shift
   if "$analyzer" -v -checks="$checks" --format=json \
        --output="$work/$name.json" "$@" >"$work/$name.log" 2>&1
   then
      echo "$name: expected violations" >&2
      cat "$work/$name.log" >&2
      exit 1
   fi
}

expect_findings() {
   if [ "$(findings "$work/$1.json")" != "$2" ]; then
      echo "$1: unexpected findings" >&2
      findings "$work/$1.json" >&2
      cat "$work/$1.log" >&2
      exit 1
   fi
}

expect_log() {
   if ! grep -F "$2" "$work/$1.log" >/dev/null; then
      echo "$1: expected in the log: $2" >&2
      cat "$work/$1.log" >&2
      exit 1
   fi
}

#  The application view: its source is analyzed, the four of the view it
#  imports resolve the names it uses and are not analyzed.
analyze app -P "$projects/app.gpr"
expect_log app 'Unit lookup covers 5 sources, 1 of them analyzed'
expect_findings app "$in_app"

#  The imported view on its own: all four of its sources are found under
#  their Apex names, the child unit and the subunit too, and analyzed.
analyze util -P "$projects/util.gpr"
expect_log util 'Unit lookup covers 4 sources, 4 of them analyzed'
expect_findings util "$in_util"

#  Without a project: the sources named on the command line are analyzed
#  and resolve one another whatever their names.
analyze files $(find "$views" -name '*.ada' | LC_ALL=C sort)
expect_log files 'Unit lookup covers 5 sources, 5 of them analyzed'
expect_findings files "$in_app
$in_util"

#  The compiler checks compile a project with gprbuild, which finds the
#  sources by the project's naming scheme. Sources named on the command
#  line are compiled by gcc, which looks for counters.ads: a warning says
#  they could not be compiled.
compiler='-checks=-*,Compiler_Warning'
"$analyzer" "$compiler" -rule-param=Compiler_Warning.options=u \
   -P "$projects/app.gpr" >"$work/compiler.log" 2>&1 || true
if grep -F 'the compiler checks need' "$work/compiler.log" >/dev/null; then
   echo "Apex view compiler checks skipped: no GNAT compiler found"
else
   expect_log compiler \
      'main.2.ada:6:4: warning: variable "Spare" is never read and never assigned (-gnatwu) [Compiler_Warning]'
   if grep -F 'could not compile' "$work/compiler.log" >/dev/null; then
      echo "compiler: the project did not compile cleanly" >&2
      cat "$work/compiler.log" >&2
      exit 1
   fi
   "$analyzer" "$compiler" -rule-param=Compiler_Warning.options=u \
      $(find "$views" -name '*.ada' | LC_ALL=C sort) \
      >"$work/compiler_files.log" 2>&1 || true
   expect_log compiler_files 'the compiler checks could not compile'
fi

echo "Apex view tests passed"
