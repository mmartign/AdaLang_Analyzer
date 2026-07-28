#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
case "$analyzer" in
   /*) : ;;
   *) analyzer="$(pwd)/$analyzer" ;;
esac

work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-config-file.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

cd "$work"

cat >sample.adb <<'EOF'
procedure Sample is
   X : Integer := 1;
begin
   if X = X then
      null;
   end if;
end Sample;
EOF

#  Auto-discovery: a config file in the current directory is picked up with
#  no flags at all, and the check it names is the one that actually fires.
cat >adalang_analyzer.cfg <<'EOF'
# adalang_analyzer.cfg
-checks=Same_Operand
EOF
if "$analyzer" sample.adb >text1 2>&1
then
   echo "expected the auto-discovered config file to find a violation" >&2
   cat text1 >&2
   exit 1
fi
grep -F '[Same_Operand]' text1 >/dev/null
grep -F 'Violations    : 1' text1 >/dev/null

#  A real command-line flag is processed after the config file's tokens, so
#  it overrides what the config file selected: here, '-checks=-*' disables
#  every check the config file had turned on.
"$analyzer" -checks=-* sample.adb >text2 2>&1
if grep -F '[Same_Operand]' text2 >/dev/null
then
   echo "real command-line flag did not override the config file" >&2
   cat text2 >&2
   exit 1
fi
grep -F 'Violations    : 0' text2 >/dev/null

#  --config=<file> loads an explicitly named file even when no
#  default-named file is present.
rm -f adalang_analyzer.cfg
cat >custom.cfg <<'EOF'
-checks=Same_Operand
EOF
if "$analyzer" --config=custom.cfg sample.adb >text3 2>&1
then
   echo "expected --config=custom.cfg to find a violation" >&2
   cat text3 >&2
   exit 1
fi
grep -F '[Same_Operand]' text3 >/dev/null

#  --no-config disables auto-discovery even when a default-named file is
#  present; with no other checks requested, the run falls back to the
#  existing "no checks enabled" warning instead of silently using it.
cat >adalang_analyzer.cfg <<'EOF'
-checks=Same_Operand
EOF
"$analyzer" --no-config sample.adb >text4 2>&1
grep -F 'no checks are enabled' text4 >/dev/null
grep -F 'Violations    : 0' text4 >/dev/null

#  An explicit --config=<file> naming a file that does not exist is a hard
#  error, not a silent fall-through to "no config file".
if "$analyzer" --config=does-not-exist.cfg sample.adb >text5 2>&1
then
   echo "expected a missing --config file to fail" >&2
   cat text5 >&2
   exit 1
fi
grep -F 'config file not found' text5 >/dev/null

#  An unrecognized token inside the config file surfaces through the same
#  "unknown option" path a bad command-line flag would, plus a note
#  identifying how many leading arguments came from the config file so the
#  error is not mysterious about where the bad token came from.
cat >adalang_analyzer.cfg <<'EOF'
--not-a-real-flag
EOF
if "$analyzer" sample.adb >text6 2>&1
then
   echo "expected an invalid config-file token to fail" >&2
   cat text6 >&2
   exit 1
fi
grep -F "unknown option '--not-a-real-flag'" text6 >/dev/null
grep -F 'expanded from config file' text6 >/dev/null

#  --config and --no-config together are a conflicting request, rejected
#  outright rather than silently picking one.
if "$analyzer" --config=custom.cfg --no-config sample.adb >text7 2>&1
then
   echo "expected --config combined with --no-config to fail" >&2
   cat text7 >&2
   exit 1
fi
grep -F 'cannot be combined' text7 >/dev/null

echo "config file tests passed"
