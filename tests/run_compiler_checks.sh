#!/bin/sh
set -eu

#  The compiler checks (Compiler_Warning, Compiler_Style_Check,
#  Compiler_Restriction) run GNAT on the sources and report its messages.

analyzer=${ANALYZER:-./bin/adalang_analyzer}
fixture=tests/precision_compiler_checks.adb
clean=tests/precision_compiler_checks_clean.ads
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-compiler-checks.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

all='-checks=-*,Compiler_Warning,Compiler_Style_Check,Compiler_Restriction'

"$analyzer" "$all" -rule-param=Compiler_Warning.options=u "$fixture" >"$work/out" 2>&1 || true
if grep -F 'the compiler checks need' "$work/out" >/dev/null
then
   echo "compiler checks tests skipped: no GNAT compiler found"
   exit 0
fi

expect() {
   wanted=$1
   shift
   if ! grep -F -- "$wanted" "$work/out" >/dev/null
   then
      echo "compiler checks: expected '$wanted' from: $*" >&2
      cat "$work/out" >&2
      exit 1
   fi
}

reject() {
   unwanted=$1
   shift
   if grep -F -- "$unwanted" "$work/out" >/dev/null
   then
      echo "compiler checks: unexpected '$unwanted' from: $*" >&2
      cat "$work/out" >&2
      exit 1
   fi
}

#  Each check reports the messages its parameter selects, and no other.
"$analyzer" "$all" -rule-param=Compiler_Warning.options=u "$fixture" >"$work/out" 2>&1 || true
expect 'unit "Ada.Text_IO" is not referenced (-gnatwu) [Compiler_Warning]' warnings u
expect ':3:4: warning: variable "Spare" is never read and never assigned' warnings u
reject 'could be declared constant' warnings u
reject '[Compiler_Style_Check]' warnings u
reject '[Compiler_Restriction]' warnings u

"$analyzer" "$all" -rule-param=Compiler_Warning.options=a "$fixture" >"$work/out" 2>&1 || true
expect '"Item" is not modified, could be declared constant (-gnatwk) [Compiler_Warning]' warnings a

"$analyzer" "$all" -rule-param=Compiler_Style_Check.options=y "$fixture" >"$work/out" 2>&1 || true
expect ':7:5: warning: bad indentation (-gnaty0) [Compiler_Style_Check]' style y
reject '[Compiler_Warning]' style y

"$analyzer" "$all" '-rule-param=Compiler_Restriction.restrictions=No_Allocators, No_Dependence => Ada.Text_IO' "$fixture" >"$work/out" 2>&1 || true
expect ':5:19: warning: violation of restriction "No_Allocators" [Compiler_Restriction]' restrictions
expect 'violation of restriction "No_Dependence => Ada.Text_IO" [Compiler_Restriction]' restrictions
reject "$work" restrictions
reject 'restrictions.adc' restrictions

#  Without parameters the checks report nothing, and a clean file stays
#  clean with them.
"$analyzer" "$all" "$fixture" >"$work/out" 2>&1 || true
expect 'Violations    : 0' no parameters
"$analyzer" "$all" -rule-param=Compiler_Warning.options=a -rule-param=Compiler_Style_Check.options=y \
   -rule-param=Compiler_Restriction.restrictions=No_Allocators "$clean" >"$work/out" 2>&1 || true
expect 'Violations    : 0' clean file

#  Nothing is left next to the sources.
if ls tests/precision_compiler_checks*.ali tests/precision_compiler_checks*.o >/dev/null 2>&1
then
   echo "compiler checks: by-products left next to the sources" >&2
   exit 1
fi

#  Through a project file the project's own switches do not leak in.
if command -v gprbuild >/dev/null 2>&1
then
   mkdir "$work/prj"
   cp "$fixture" "$work/prj/"
   cat >"$work/prj/p.gpr" <<'GPR'
project P is
   for Source_Dirs use (".");
   for Object_Dir use "obj";
   package Compiler is
      for Default_Switches ("Ada") use ("-gnatwae", "-gnatyy");
   end Compiler;
end P;
GPR
   "$analyzer" "$all" -rule-param=Compiler_Warning.options=u "-P$work/prj/p.gpr" >"$work/out" 2>&1 || true
   expect 'unit "Ada.Text_IO" is not referenced (-gnatwu) [Compiler_Warning]' project
   reject 'could be declared constant' project
   reject '[Compiler_Style_Check]' project
   if [ -d "$work/prj/obj" ] && [ -n "$(ls -A "$work/prj/obj")" ]
   then
      echo "compiler checks: by-products left in the project's object directory" >&2
      exit 1
   fi
fi

echo "compiler checks tests passed"
