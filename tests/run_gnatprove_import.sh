#!/bin/sh
set -eu

#  --gnatprove-log: what GNATprove said of a check is set beside the
#  obligation that stands for it, and never in its place.
#
#  tests/gnatprove_import/gnatprove.log is what GNATprove (FSF 16.1.0,
#  "--mode=all --level=1 --report=all --output=oneline") wrote for the two
#  sources next to it. made_up.log is written by hand, for what a run on
#  these sources does not give: a verdict against AdaLang's, a check of a
#  generic unit repeated for its instances, a justified check, a file that
#  is not analyzed, a path with directories.

analyzer=${ANALYZER:-./bin/adalang_analyzer}
sources="tests/gnatprove_import/sample.ads tests/gnatprove_import/sample.adb"
log=tests/gnatprove_import/gnatprove.log
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-gnatprove-import.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

run_json()
{
   output=$1
   shift
   status=0
   # shellcheck disable=SC2086
   "$analyzer" --verify -q --format=json --output="$output" "$@" $sources ||
     status=$?
   if [ "$status" -gt 1 ]; then
      echo "gnatprove import: run failed with status $status ($*)" >&2
      exit "$status"
   fi
}

run_json "$work/plain.json"
run_json "$work/real.json" --gnatprove-log="$log"
run_json "$work/made_up.json" \
  --gnatprove-log tests/gnatprove_import/made_up.log
run_json "$work/both.json" --gnatprove-log="$log" \
  --gnatprove-log=tests/gnatprove_import/made_up.log

#  The ledger pairs the same report with the same log on its own.
python3 benchmarks/gnatprove_gap_ledger.py "$work/plain.json" "$log" \
  --rows "$work/rows.tsv" >/dev/null

python3 - "$work" <<'PYTHON'
import csv
import json
import sys

work = sys.argv[1]


def load(name):
    with open(f"{work}/{name}.json") as report:
        return json.load(report)


def fail(message):
    sys.exit("gnatprove import: " + message)


plain, real, made_up, both = (load(name) for name in
                              ("plain", "real", "made_up", "both"))

# 1. Without a log the report has nothing of GNATprove's.
if "gnatproveImport" in plain or "gnatproveChecks" in plain:
    fail("a run without a log reports GNATprove verdicts")
if any("gnatprove" in item for item in plain["proofObligations"]):
    fail("a run without a log gives an obligation a GNATprove verdict")

# 2. With one, everything that is AdaLang's is as it was.
for name, report in (("real", real), ("made_up", made_up), ("both", both)):
    stripped = [
        {key: value for key, value in item.items() if key != "gnatprove"}
        for item in report["proofObligations"]
    ]
    if stripped != plain["proofObligations"]:
        fail(f"{name}: the log changed an obligation of AdaLang's")
    for key in ("proofSummary", "findings"):
        if report[key] != plain[key]:
            fail(f"{name}: the log changed {key}")


def expect(report, name, **counts):
    summary = report["gnatproveImport"]
    for key, value in counts.items():
        if summary[key] != value:
            fail(f"{name}: {key} is {summary[key]}, expected {value}")
    proved = (summary["provedByBoth"]
              + summary["provedByGnatproveOnObligation"]
              + summary["provedByGnatproveWithoutObligation"]
              + summary["definiteErrorWhereGnatproveProved"])
    if proved != summary["proved"]:
        fail(f"{name}: a check GNATprove proved is not accounted for")


def check_at(report, file, line, column, label):
    found = [item for item in report["gnatproveChecks"]
             if (item["file"], item["line"], item["column"],
                 item["check"]) == (file, line, column, label)]
    if len(found) != 1:
        fail(f"{len(found)} checks '{label}' at {file}:{line}:{column}")
    return found[0]


def obligation(report, identifier):
    found = [item for item in report["proofObligations"]
             if item["id"] == identifier]
    if len(found) != 1:
        fail(f"{len(found)} obligations with the id {identifier}")
    return found[0]


# 3. GNATprove's own log: fourteen checks, eleven of them proved. Nine
#    AdaLang proves too; one it has an obligation for and leaves unproved;
#    one, the length check, it has no obligation for.
expect(real, "real", checks=14, proved=11, justified=0, notProved=3,
       provedByBoth=9, provedByGnatproveOnObligation=1,
       provedByGnatproveWithoutObligation=1,
       definiteErrorWhereGnatproveProved=0,
       provedSafeWhereGnatproveNotProved=0)

overflow = check_at(real, "sample.ads", 18, 25, "overflow check")
if (overflow["verdict"], overflow["adalang"]) != ("proved", "unproved"):
    fail("the addition only GNATprove proves is " + str(overflow))
carried = obligation(real, overflow["obligation"])
if (carried["status"], carried.get("gnatprove")) != ("unproved", "proved"):
    fail("the obligation of that addition is " + str(carried))

length = check_at(real, "sample.adb", 5, 14, "length check")
if (length["adalang"], length["obligation"], length["kind"]) != (
        "no such obligation kind", None, None):
    fail("the length check is " + str(length))

#    A check at another column of the line goes to the nearest obligation.
division = check_at(real, "sample.ads", 9, 61, "division check")
if obligation(real, division["obligation"])["column"] != 63:
    fail("the division check went to " + str(division))

#    A check GNATprove did not prove says so on the obligation.
by_zero = check_at(real, "sample.adb", 11, 20, "divide by zero")
zero = obligation(real, by_zero["obligation"])
if (zero["status"], zero["gnatprove"]) != ("definite-error", "not-proved"):
    fail("the division by zero is " + str(zero))

# 4. The ledger, given the same report and log, pairs every check alike.
with open(f"{work}/rows.tsv") as rows:
    ledger = {
        (row["file"], int(row["line"]), int(row["column"]),
         row["gnatprove_check"]): (row["gnatprove"], row["adalang"])
        for row in csv.DictReader(rows, delimiter="\t")
        if row["gnatprove"] != "no check"
    }
imported = {
    (item["file"], item["line"], item["column"], item["check"]):
        (item["verdict"].replace("-", " "), item["adalang"])
    for item in real["gnatproveChecks"]
}
if ledger != imported:
    fail("the ledger and the import pair differently:\n"
         f"  ledger only: {sorted(set(ledger.items()) - set(imported.items()))}\n"
         f"  import only: {sorted(set(imported.items()) - set(ledger.items()))}")

# 5. The made-up log.
expect(made_up, "made_up", checks=7, proved=4, justified=1, notProved=2,
       provedByBoth=1, provedByGnatproveOnObligation=0,
       provedByGnatproveWithoutObligation=2,
       definiteErrorWhereGnatproveProved=1,
       provedSafeWhereGnatproveNotProved=1)

#    The verdict that goes against AdaLang's leaves AdaLang's as it is.
against = check_at(made_up, "sample.adb", 11, 20, "division check")
error = obligation(made_up, against["obligation"])
if (error["status"], error["gnatprove"]) != ("definite-error", "proved"):
    fail("a definite error GNATprove is said to prove is " + str(error))
doubted = check_at(made_up, "sample.ads", 9, 61, "divide by zero")
safe = obligation(made_up, doubted["obligation"])
if (safe["status"], safe["gnatprove"]) != ("proved-safe", "not-proved"):
    fail("a proof GNATprove is said not to have is " + str(safe))

#    Three messages for three instances are one check, as good as the
#    worst; the line that goes on from another and the warning are none.
instances = check_at(made_up, "sample.ads", 18, 25, "overflow check")
if (instances["instances"], instances["verdict"]) != (3, "not-proved"):
    fail("the check of three instances is " + str(instances))

justified = check_at(made_up, "sample.ads", 13, 12, "divide by zero")
if justified["verdict"] != "justified":
    fail("the justified check is " + str(justified))
if obligation(made_up, justified["obligation"])["gnatprove"] != "justified":
    fail("the justified check does not say so on its obligation")

other = check_at(made_up, "other.adb", 3, 4, "range check")
if other["adalang"] != "file without any obligation":
    fail("the check of a file that is not analyzed is " + str(other))
nowhere = check_at(made_up, "sample.ads", 30, 5, "range check")
if nowhere["adalang"] != "no obligation here":
    fail("the check where AdaLang has none is " + str(nowhere))

#    A path with directories is the file of that name.
pathed = check_at(made_up, "sample.ads", 12, 13, "Always_Terminates")
if pathed["adalang"] != "proved-safe":
    fail("the check given with a path is " + str(pathed))

# 6. Two logs are read as one: twenty-one checks, of which three are in
#    both -- the same check at the same place.
expect(both, "both", checks=18)
if len(both["gnatproveImport"]["logs"]) != 2:
    fail("two logs were not both recorded")
PYTHON

#  The text report says whose the verdicts are.
# shellcheck disable=SC2086
"$analyzer" --verify --gnatprove-log="$log" $sources >"$work/text" 2>&1 ||
  true
grep -F "GNATprove verdicts (read from 1 log; not AdaLang's own results):" \
  "$work/text" >/dev/null
grep -F 'Checks in the log : 14 (11 proved, 0 justified, 3 not proved)' \
  "$work/text" >/dev/null
grep -F 'proved by AdaLang too : 9' "$work/text" >/dev/null
grep -F "GNATprove's verdict alone, on an AdaLang obligation : 1" \
  "$work/text" >/dev/null
grep -F "GNATprove's verdict alone, no AdaLang obligation : 1" \
  "$work/text" >/dev/null

# shellcheck disable=SC2086
"$analyzer" --verify -v --gnatprove-log="$log" $sources >"$work/verbose" 2>&1 ||
  true
grep -F '      GNATprove: proved' "$work/verbose" >/dev/null
grep -F '      GNATprove: not-proved' "$work/verbose" >/dev/null

#  SARIF carries the counts and the verdict of each obligation.
# shellcheck disable=SC2086
"$analyzer" --verify -q --format=sarif --output="$work/report.sarif" \
  --gnatprove-log="$log" $sources || true
grep -F '"gnatproveImport": {"logs": [' "$work/report.sarif" >/dev/null
grep -F '"gnatprove": "proved"' "$work/report.sarif" >/dev/null
python3 -c 'import json, sys; json.load(open(sys.argv[1]))' \
  "$work/report.sarif"

#  The verdicts go beside obligations, which only --verify raises.
# shellcheck disable=SC2086
if "$analyzer" -q --recommended --gnatprove-log="$log" $sources \
     >"$work/no-verify" 2>&1
then
   echo "gnatprove import: accepted without --verify" >&2
   exit 1
fi
grep -F -- '--gnatprove-log requires --verify' "$work/no-verify" >/dev/null

# shellcheck disable=SC2086
if "$analyzer" --verify -q --gnatprove-log="$work/absent.log" $sources \
     >"$work/absent" 2>&1
then
   echo "gnatprove import: a log that is not there was accepted" >&2
   exit 1
fi
grep -F 'could not read GNATprove log' "$work/absent" >/dev/null

if "$analyzer" --verify -q --gnatprove-log >"$work/no-argument" 2>&1
then
   echo "gnatprove import: accepted without a file name" >&2
   exit 1
fi
grep -F 'expected argument for --gnatprove-log' "$work/no-argument" \
  >/dev/null

echo "GNATprove import tests passed"
