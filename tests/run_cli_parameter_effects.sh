#!/bin/sh
set -eu

#  Existing suites exercise most CLI switches incidentally, but nothing
#  systematically proves each one actually changes analyzer behavior rather
#  than being parsed and silently dropped. This suite closes that gap for
#  -parameter-threshold, -nesting-threshold, -line-length-threshold, the
#  -R/+R per-check switches, and "--" as the option/file-name separator.

analyzer=${ANALYZER:-./bin/adalang_analyzer}
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-cli-parameter-effects.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

#  -P/-X, --format/--output, --baseline/--write-baseline, -checks=, -v/-q,
#  --config/--no-config, --do178c/--compliance-report and the presets are
#  all already proven end-to-end elsewhere (run_reporting.sh,
#  run_config_file.sh, run_compliance_report.sh, run_automotive.sh,
#  run_verification.sh, run_cli_robustness.sh); this suite deliberately
#  does not re-cover them.

#  --- -parameter-threshold=<n> / -parameter-threshold <n> ---------------

"$analyzer" -q -checks=Too_Many_Parameters \
  tests/cli_parameter_threshold.adb

for form in "-parameter-threshold=3" "-parameter-threshold 3"; do
   if "$analyzer" -checks=Too_Many_Parameters $form \
        tests/cli_parameter_threshold.adb >"$work/out" 2>&1
   then
      echo "expected $form to lower the parameter threshold below 4" >&2
      cat "$work/out" >&2
      exit 1
   fi
   grep -F 'exceeds threshold 3' "$work/out" >/dev/null || {
      echo "$form: threshold value was not threaded into the finding" >&2
      cat "$work/out" >&2
      exit 1
   }
done

#  --- -nesting-threshold=<n> / -nesting-threshold <n> --------------------

"$analyzer" -q -checks=Deep_Nesting \
  tests/cli_nesting_threshold.adb

for form in "-nesting-threshold=2" "-nesting-threshold 2"; do
   if "$analyzer" -checks=Deep_Nesting $form \
        tests/cli_nesting_threshold.adb >"$work/out" 2>&1
   then
      echo "expected $form to lower the nesting threshold below 3" >&2
      cat "$work/out" >&2
      exit 1
   fi
   grep -F 'exceeds threshold 2' "$work/out" >/dev/null || {
      echo "$form: threshold value was not threaded into the finding" >&2
      cat "$work/out" >&2
      exit 1
   }
done

#  --- -line-length-threshold=<n> / -line-length-threshold <n> ------------
#  Built at a controlled length rather than checked in, so the boundary
#  this test relies on can never silently drift under editing/reformatting.

prefix='   null; -- '
pad_len=$((90 - ${#prefix}))
pad=$(awk -v n="$pad_len" 'BEGIN { s = ""; for (i = 0; i < n; i++) s = s "x"; print s }')
{
   echo "procedure Cli_Line_Length_Threshold is"
   echo "begin"
   printf '%s\n' "${prefix}${pad}"
   echo "end Cli_Line_Length_Threshold;"
} >"$work/cli_line_length_threshold.adb"

"$analyzer" -q -checks=Long_Line \
  "$work/cli_line_length_threshold.adb"

for form in "-line-length-threshold=80" "-line-length-threshold 80"; do
   if "$analyzer" -checks=Long_Line $form \
        "$work/cli_line_length_threshold.adb" >"$work/out" 2>&1
   then
      echo "expected $form to lower the line-length threshold below 90" >&2
      cat "$work/out" >&2
      exit 1
   fi
   grep -F 'exceeds threshold 80' "$work/out" >/dev/null || {
      echo "$form: threshold value was not threaded into the finding" >&2
      cat "$work/out" >&2
      exit 1
   }
done

#  --- -R<check> / +R<check> ----------------------------------------------

if "$analyzer" -checks=Too_Many_Parameters,Deep_Nesting \
     -parameter-threshold=3 -nesting-threshold=2 \
     tests/cli_switch_toggle.adb >"$work/out" 2>&1
then
   echo "expected both checks to fire before any -R/+R override" >&2
   cat "$work/out" >&2
   exit 1
fi
grep -F '[Too_Many_Parameters]' "$work/out" >/dev/null
grep -F '[Deep_Nesting]' "$work/out" >/dev/null

if "$analyzer" -checks=Too_Many_Parameters,Deep_Nesting \
     -parameter-threshold=3 -nesting-threshold=2 -RDeep_Nesting \
     tests/cli_switch_toggle.adb >"$work/out" 2>&1
then
   echo "expected -RDeep_Nesting to leave Too_Many_Parameters firing" >&2
   cat "$work/out" >&2
   exit 1
fi
grep -F '[Too_Many_Parameters]' "$work/out" >/dev/null
if grep -F '[Deep_Nesting]' "$work/out" >/dev/null; then
   echo "-RDeep_Nesting did not suppress Deep_Nesting" >&2
   cat "$work/out" >&2
   exit 1
fi

if "$analyzer" -checks=-* -parameter-threshold=3 -nesting-threshold=2 \
     +RToo_Many_Parameters tests/cli_switch_toggle.adb >"$work/out" 2>&1
then
   echo "expected +RToo_Many_Parameters to re-enable it after -checks=-*" >&2
   cat "$work/out" >&2
   exit 1
fi
grep -F '[Too_Many_Parameters]' "$work/out" >/dev/null
if grep -F '[Deep_Nesting]' "$work/out" >/dev/null; then
   echo "+RToo_Many_Parameters unexpectedly re-enabled Deep_Nesting too" >&2
   cat "$work/out" >&2
   exit 1
fi

#  --- "--" as the option/file-name separator ------------------------------
#  A source file whose bare name starts with '-' is indistinguishable from
#  an option unless "--" tells the parser to stop looking for switches.

dash_file="$work/-cli_dash_named.adb"
{
   echo "procedure Cli_Dash_Named is"
   echo "begin"
   echo "   null;"
   echo "end Cli_Dash_Named;"
} >"$dash_file"

if (
   cd "$work" && case "$analyzer" in
      /*) : ;;
      *) analyzer="$OLDPWD/$analyzer" ;;
   esac
   "$analyzer" -q -- -cli_dash_named.adb
)
then
   :
else
   echo "'--' did not let a dash-prefixed file name through" >&2
   exit 1
fi

if (
   cd "$work" && case "$analyzer" in
      /*) : ;;
      *) analyzer="$OLDPWD/$analyzer" ;;
   esac
   "$analyzer" -q -cli_dash_named.adb >out 2>&1
)
then
   echo "a dash-prefixed file name without '--' should have been rejected as an unknown option" >&2
   exit 1
fi
grep -F "unknown option '-cli_dash_named.adb'" "$work/out" >/dev/null || {
   echo "dash-prefixed file name without '--' failed for the wrong reason" >&2
   cat "$work/out" >&2
   exit 1
}

echo "cli parameter effects tests passed"
