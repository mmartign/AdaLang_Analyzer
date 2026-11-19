#!/bin/sh
set -eu

#  ObjectAda project files (.prj). tests/objectada_project holds a legacy
#  application saved by Aonix ObjectAda 7.2 (app/legacy.prj) that links to
#  the library of a project saved by PTC ObjectAda64 10 (common/common.prj),
#  both written by tests/gen_objectada_projects.py. Their absolute paths are
#  those of the Windows machine where they were last saved; the sources are
#  named as ObjectAda allows (Sensors.SPC, a file of two units), in another
#  case than on disk, and end their lines with CR LF.

analyzer=${ANALYZER:-./bin/adalang_analyzer}
project=tests/objectada_project
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-objectada.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

#  The project files are what the generator writes.
if command -v python3 >/dev/null 2>&1 \
  && python3 -c 'import sys; sys.exit(sys.version_info < (3, 6))'
then
   mkdir "$work/generated" "$work/generated/app" "$work/generated/common"
   python3 tests/gen_objectada_projects.py "$work/generated"
   for file in app/legacy.prj common/common.prj; do
      if ! cmp -s "$work/generated/$file" "$project/$file"; then
         echo "$project/$file is not what tests/gen_objectada_projects.py" \
              "writes" >&2
         exit 1
      fi
   done
fi

#  Long_Line finds a line of units.ads, in the library: when units.ads is
#  analyzed, and not when it is only looked up.
checks='Known_Range_Check_Failure,Long_Line'

#  The legacy application: its listed sources are analyzed, those of the
#  library it links to resolve the names it uses and are not analyzed.
if "$analyzer" -v -checks="$checks" --format=json \
     --output="$work/legacy.json" -P "$project/app/legacy.prj" \
     >"$work/legacy.log" 2>&1
then
   echo "expected legacy.prj to produce violations" >&2
   cat "$work/legacy.log" >&2
   exit 1
fi

expect_log() {
   if ! grep -F "$1" "$work/legacy.log" >/dev/null; then
      echo "legacy.prj: expected in the log: $1" >&2
      cat "$work/legacy.log" >&2
      exit 1
   fi
}
expect_log ', target Win32 (Intel) Debug: 5 sources listed, 4 found, 1 library sources'
expect_log 'Unit lookup covers 5 sources, 4 of them analyzed'
expect_log 'legacy.prj: listed source not found: ..\..\src\retired.adb'
expect_log 'legacy.prj: no source found for library c:\program files\aonix\objectada\win32ada\binding\lib; the names it declares will not resolve'
if grep -F 'no source found for library C:\Old Place' "$work/legacy.log" \
     >/dev/null
then
   echo "legacy.prj: the library of common.prj was not found" >&2
   cat "$work/legacy.log" >&2
   exit 1
fi

#  Two findings in the second unit of control.ada, named as it is on disk.
#  One needs Sensors, from sensors.spc; the other Units, from the library.
#  The fingerprints are those of every host: the path is relative and has
#  '/' separators, and the line is read without its CR.
#  Python on Windows ends a line with CR LF: the CRs are dropped.
findings=$(python3 - "$work/legacy.json" <<'PY' 2>/dev/null | tr -d '\r' || true
import json, sys
for f in json.load(open(sys.argv[1]))["findings"]:
    print(f["file"], f["line"], f["column"], f["ruleId"], f["fingerprint"])
PY
)
if [ -z "$findings" ]; then
   #  Without Python, from the report's own lines.
   findings=$(sed -n 's/.*"file": "\([^"]*\)", "line": \([0-9]*\), "column": \([0-9]*\).*/\1 \2 \3/p' \
      "$work/legacy.json")
   expected="tests/objectada_project/src/control.ada 14 15
tests/objectada_project/src/control.ada 15 15"
else
   expected="tests/objectada_project/src/control.ada 14 15 Known_Range_Check_Failure 2bb295cb9b72139f
tests/objectada_project/src/control.ada 15 15 Known_Range_Check_Failure 2f2ed422aa5bfaff"
fi
if [ "$findings" != "$expected" ]; then
   echo "legacy.prj: unexpected findings" >&2
   echo "$findings" >&2
   exit 1
fi

#  SARIF names the file by a relative URI.
"$analyzer" -checks="$checks" --format=sarif --output="$work/legacy.sarif" \
   -P "$project/app/legacy.prj" >/dev/null 2>&1 || true
if ! grep -F '"uri": "tests/objectada_project/src/control.ada"' \
     "$work/legacy.sarif" >/dev/null
then
   echo "legacy.prj: unexpected SARIF location" >&2
   grep -F '"uri"' "$work/legacy.sarif" >&2 || true
   exit 1
fi

#  The library on its own: its source is analyzed then.
if "$analyzer" -checks="$checks" -P "$project/common/common.prj" \
     >"$work/common.log" 2>&1
then
   echo "expected common.prj to produce a violation" >&2
   exit 1
fi
if [ "$(grep -c '\[Long_Line\]' "$work/common.log")" -ne 1 ] \
  || ! grep -F 'units.ads:4:121: warning: line length 126 exceeds threshold 120' \
         "$work/common.log" >/dev/null
then
   echo "common.prj: unexpected findings" >&2
   cat "$work/common.log" >&2
   exit 1
fi

#  Files that are not ObjectAda project files, or are cut short, are
#  reported, not crashed on.
printf 'src_dir=./\nmain=x.adb\n' >"$work/text.prj"
head -c 100 "$project/app/legacy.prj" >"$work/short.prj"
head -c 1000 "$project/app/legacy.prj" >"$work/cut.prj"
for broken in text short cut; do
   status=0
   "$analyzer" -checks="$checks" -P "$work/$broken.prj" \
      >"$work/$broken.log" 2>&1 || status=$?
   #  The path as the analyzer names it: on Windows, Git Bash's /tmp is
   #  given to it as C:/Users/.../Temp.
   if [ "$status" -eq 0 ] \
     || ! grep -E "could not read ObjectAda project .*/$broken\.prj: " \
            "$work/$broken.log" >/dev/null
   then
      echo "$broken.prj: expected an error reading it" >&2
      cat "$work/$broken.log" >&2
      exit 1
   fi
done

#  A project of which no source is found.
mkdir "$work/moved"
cp "$project/app/legacy.prj" "$work/moved/legacy.prj"
if "$analyzer" -checks="$checks" -P "$work/moved/legacy.prj" \
     >"$work/moved.log" 2>&1 \
  || ! grep -F 'none of its sources was found' "$work/moved.log" >/dev/null
then
   echo "a project none of whose sources exist was not reported" >&2
   cat "$work/moved.log" >&2
   exit 1
fi

#  Directories with an entry whose attributes cannot be read: on Windows a
#  drive root (pagefile.sys, System Volume Information), here a symbolic
#  link that loops. Such an entry above the project, among its sources,
#  beside the library's project or in the library made every source go
#  missing, as on a Windows runner whose D:\ had one (2026-11-19).
looped="$work/looped"
mkdir "$looped"
cp -R "$project" "$looped/"
loops=yes
for directory in "$looped" "$looped/objectada_project/src" \
   "$looped/objectada_project/common" \
   "$looped/objectada_project/common/units"
do
   if ! ln -s loop "$directory/loop" 2>/dev/null || [ ! -L "$directory/loop" ]
   then
      loops=no
   fi
done
if [ "$loops" = yes ]; then
   "$analyzer" -v -checks="$checks" \
      -P "$looped/objectada_project/app/legacy.prj" >"$work/looped.log" 2>&1 \
      || true
   if ! grep -F ', target Win32 (Intel) Debug: 5 sources listed, 4 found, 1 library sources' \
          "$work/looped.log" >/dev/null \
     || grep -F 'no source found for library C:\Old Place' "$work/looped.log" \
          >/dev/null
   then
      echo "legacy.prj: an unreadable directory entry hid its sources" >&2
      cat "$work/looped.log" >&2
      exit 1
   fi
fi

echo "ObjectAda project tests passed"
