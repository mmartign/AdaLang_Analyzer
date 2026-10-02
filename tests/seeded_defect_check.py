#!/usr/bin/env python3
"""Seeded-defect oracle for --verify.

Every fixture under tests/seeded_defects/ is a small program in which marked
lines carry a check whose outcome is known by construction:

  --  BAD          the outermost division on the line can divide by zero
  --  BAD:kind     every obligation of that kind on the line can fail
  --  OK           the outermost division on the line cannot divide by zero
  --  OK:kind      no obligation of that kind on the line can fail

A selected obligation that is proved-safe or unreachable on a BAD line is a
false-safe result and always fails the run. The GNATprove-oracle corpora
cannot find such a defect: on code that is proved correct, a bogus proof
agrees with the oracle.

quality/seeded_defect_outcomes.tsv additionally pins the outcome of every
marked line, so a BAD line that silently loses its obligation (which would
make the probe vacuous) or an OK line that stops proving (a precision
regression) also fails the run. After an intended change, regenerate it with
--update and review the diff.

Usage: python3 tests/seeded_defect_check.py [--update] [-v]
"""
import collections
import concurrent.futures
import json
import os
import re
import subprocess
import sys

FIXTURES = "tests/seeded_defects"
BASELINE = "quality/seeded_defect_outcomes.tsv"
HEADER = "# fixture\tline\tmarker\tkind\toutcome\n"
MARKER = re.compile(r"--  (BAD|OK)(?::([a-z-]+))?")
FALSE_SAFE = ("proved-safe", "unreachable")

analyzer = os.environ.get("ANALYZER", "./bin/adalang_analyzer")
jobs = int(os.environ.get("ADALANG_SEEDED_DEFECT_JOBS", "0")) or min(
    4, os.cpu_count() or 1
)


def analyze(body):
    """Return (rows, false-safe messages, error) for one fixture body."""
    name = os.path.basename(body)
    spec = body[:-4] + ".ads"
    command = [analyzer, "--verify", "-q", "--no-config", "--format=json"]
    if os.path.exists(spec):
        command.append(spec)
    command.append(body)
    run = subprocess.run(command, capture_output=True, text=True)
    if run.returncode > 1:
        return [], [], "%s: analyzer exit status %d" % (name, run.returncode)
    if "Error processing" in run.stderr or "recoverable" in run.stderr:
        return [], [], "%s: %s" % (name, run.stderr.strip()[:300])
    try:
        obligations = json.loads(run.stdout)["proofObligations"]
    except (ValueError, KeyError):
        return [], [], "%s: no JSON report" % name

    by_line = collections.defaultdict(list)
    for obligation in obligations:
        if os.path.basename(obligation["file"]) == name:
            by_line[obligation["line"]].append(obligation)

    rows = []
    false_safes = []
    with open(body, encoding="utf-8") as source:
        for number, text in enumerate(source, 1):
            match = MARKER.search(text)
            if not match:
                continue
            marker = match.group(1)
            kind = match.group(2) or "division-by-zero"
            selected = [o for o in by_line.get(number, []) if o["kind"] == kind]
            if not match.group(2) and selected:
                #  An unqualified marker names the outermost division only.
                selected = [max(selected, key=lambda o: len(o["operation"]))]
            statuses = sorted(o["status"] for o in selected)
            rows.append(
                (name, number, marker, kind, ",".join(statuses) or "no-obligation")
            )
            if marker == "BAD":
                for obligation in selected:
                    if obligation["status"] in FALSE_SAFE:
                        false_safes.append(
                            "%s:%d [%s] %s (%s) %s"
                            % (
                                name,
                                number,
                                kind,
                                obligation["status"],
                                obligation["method"],
                                obligation["operation"],
                            )
                        )
    return rows, false_safes, None


def main():
    update = "--update" in sys.argv
    verbose = "-v" in sys.argv
    bodies = sorted(
        os.path.join(FIXTURES, entry)
        for entry in os.listdir(FIXTURES)
        if entry.endswith(".adb")
    )
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        results = list(pool.map(analyze, bodies))

    rows = []
    false_safes = []
    errors = []
    for fixture_rows, fixture_false_safes, error in results:
        rows.extend(fixture_rows)
        false_safes.extend(fixture_false_safes)
        if error:
            errors.append(error)

    for error in errors:
        print("seeded-defect run failed: " + error, file=sys.stderr)
    for message in false_safes:
        print("false-safe regression: " + message, file=sys.stderr)
    if errors or false_safes:
        return 1

    current = [HEADER] + ["%s\t%d\t%s\t%s\t%s\n" % row for row in rows]
    if verbose:
        sys.stdout.writelines(current[1:])
    if update:
        with open(BASELINE, "w", encoding="utf-8") as baseline:
            baseline.writelines(current)
    else:
        with open(BASELINE, encoding="utf-8") as baseline:
            recorded = baseline.readlines()
        if recorded != current:
            print("seeded-defect outcomes changed:", file=sys.stderr)
            before = set(recorded)
            after = set(current)
            for line in sorted(before - after):
                print("  recorded: " + line.rstrip("\n"), file=sys.stderr)
            for line in sorted(after - before):
                print("  current:  " + line.rstrip("\n"), file=sys.stderr)
            print(
                "review, then run: python3 tests/seeded_defect_check.py --update",
                file=sys.stderr,
            )
            return 1

    seeded = sum(1 for row in rows if row[2] == "BAD")
    examined = sum(
        1 for row in rows if row[2] == "BAD" and row[4] != "no-obligation"
    )
    safe = sum(1 for row in rows if row[2] == "OK")
    proved = sum(
        1
        for row in rows
        if row[2] == "OK" and set(row[4].split(",")) == {"proved-safe"}
    )
    print(
        "seeded-defect campaign: %d/%d seeded defects rejected "
        "(%d raise no obligation), %d/%d safe checks proved"
        % (examined, examined, seeded - examined, proved, safe)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
