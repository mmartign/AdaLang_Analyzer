#!/usr/bin/env python3
"""Account for every check GNATprove reports on a corpus.

For each check message of a GNATprove "--mode=prove --output=oneline" log,
this records what AdaLang Analyzer's "--verify" run did at the same place:
proved it, left it unproved, called it unsupported, or raised no obligation
at all. Unlike the per-corpus compare.awk scripts, which only count the
locations where both tools have exactly one obligation of a kind, nothing is
left out here: a check that cannot be paired is a row of its own.

Usage:
    gnatprove_gap_ledger.py <adalang-verify.json> <gnatprove-prove.oneline>
                            [--name NAME] [--rows FILE.tsv]
    gnatprove_gap_ledger.py --corpus NAME=RESULTS_DIR [--corpus ...]
                            [--rows FILE.tsv]

Prints a Markdown summary on standard output. With --rows, also writes one
line per GNATprove check (and per AdaLang obligation GNATprove has no check
for) to FILE.tsv.
"""

import argparse
import collections
import json
import os
import re
import sys

# GNATprove message text -> (group, AdaLang obligation kind or None).
# The order matters: the first pattern found in the message wins.
CHECKS = [
    ("loop invariant initialization", "assertion", "loop-invariant-initialization"),
    ("loop invariant in first iteration", "assertion", "loop-invariant-initialization"),
    ("loop invariant preservation", "assertion", "loop-invariant-preservation"),
    ("loop invariant", "assertion", "loop-invariant-preservation"),
    ("loop variant", "assertion", "loop-variant"),
    ("refined post", "assertion", None),
    ("postcondition", "assertion", "postcondition"),
    ("precondition", "assertion", "precondition"),
    ("contract case", "assertion", None),
    ("contract or exit cases", "assertion", None),
    ("contract cases", "assertion", None),
    ("default initial condition", "assertion", None),
    ("assertion", "assertion", "assertion"),
    ("overflow check", "run-time check", "integer-overflow"),
    ("division check", "run-time check", "division-by-zero"),
    ("divide by zero", "run-time check", "division-by-zero"),
    ("index check", "run-time check", "index-check"),
    ("range check", "run-time check", "range-check"),
    ("discriminant check", "run-time check", "discriminant-check"),
    ("length check", "run-time check", "length-check"),
    ("predicate check", "run-time check", None),
    ("invariant check", "run-time check", None),
    ("tag check", "run-time check", None),
    ("pointer dereference check", "run-time check", None),
    ("null exclusion check", "run-time check", None),
    ("accessibility check", "run-time check", None),
    ("initialization check", "initialization", "initialization-check"),
    ("initialization of", "initialization", "initialization-check"),
    ("might not be initialized", "initialization", "initialization-check"),
    ("is not initialized", "initialization", "initialization-check"),
    ("resource or memory leak", "ownership", None),
    ("non-aliasing", "ownership", None),
    ("aliasing", "ownership", None),
    ("Always_Terminates", "termination", "termination"),
    ("data dependencies", "flow contract", "data-dependencies"),
    ("flow dependencies", "flow contract", "flow-dependencies"),
    ("unchecked conversion", "representation", None),
    ("Container_Aggregates annotation", "annotation", None),
]

# Lines that continue the previous message or describe the run; they are
# not checks.
NOT_A_CHECK = re.compile(
    r"^(in |during |when |after |for |analyzing |add a contract|unrolling "
    r"|cannot unroll|local subprogram|no contextual analysis|justified that)"
)

# How many lines away an obligation of the same kind still counts as "near".
NEARBY = 3

MESSAGE = re.compile(r"^(.*?):(\d+):(\d+): (info|low|medium|high): (.*)$")


def label_of(text):
    """What the message is about, from what it says before its remarks.

    The remarks in brackets and the names in quotes are not looked at: a
    division check that "might fail [possible fix: add precondition ...]"
    is not a precondition, nor is the initialization of "precondition_met".
    """
    said = re.sub(r'"[^"]*"', '""', text.split(" [")[0])
    for pattern, group, kind in CHECKS:
        if pattern in said:
            return pattern, group, kind
    return None


def read_gnatprove(path):
    """The checks of a oneline log, and the messages that are not checks."""
    checks = []
    other = collections.Counter()
    with open(path, errors="replace") as log:
        for line in log:
            found = MESSAGE.match(line.rstrip("\n"))
            if not found:
                continue
            name, row, column, severity, text = found.groups()
            if NOT_A_CHECK.match(text):
                continue
            label = label_of(text)
            if label is None:
                other[re.sub(r'"[^"]*"', '"..."', text)[:60]] += 1
                continue
            pattern, group, kind = label
            if "justified" in text:
                verdict = "justified"
            elif severity == "info":
                verdict = "proved"
            else:
                verdict = "not proved"
            checks.append(
                {
                    "file": os.path.basename(name),
                    "line": int(row),
                    "column": int(column),
                    "check": pattern,
                    "group": group,
                    "kind": kind,
                    "verdict": verdict,
                }
            )
    return merge_instances(checks), other


def merge_instances(checks):
    """One check per place.

    GNATprove repeats a check of a generic unit for every instance, each
    time at the same place in the generic's source. The place is proved
    when every instance of it is.
    """
    order = ["proved", "justified", "not proved"]
    merged = {}
    for check in checks:
        key = (check["file"], check["line"], check["column"], check["check"])
        seen = merged.get(key)
        if seen is None:
            check["instances"] = 1
            merged[key] = check
        else:
            seen["instances"] += 1
            if order.index(check["verdict"]) > order.index(seen["verdict"]):
                seen["verdict"] = check["verdict"]
    return list(merged.values())


def subject_of(item):
    """The declaration an obligation is about, as (file, line, column)."""
    subject = item.get("subject")
    if not subject:
        return None
    return (os.path.basename(subject["file"]), subject["line"],
            subject["column"])


def read_adalang(path):
    with open(path) as report:
        data = json.load(report)
    obligations = []
    for item in data.get("proofObligations", []):
        obligations.append(
            {
                "file": os.path.basename(item["file"]),
                "line": item["line"],
                "column": item.get("column", 0),
                "kind": item["kind"],
                "status": item["status"],
                "reason": item.get("imprecisionSource", "") or "",
                "subject": subject_of(item),
                "used": False,
            }
        )
    return obligations


def pair(checks, obligations):
    """Give each GNATprove check the AdaLang obligation it corresponds to.

    Candidates have the same file, line and kind. The one at the same
    column is taken if there is one, then the nearest unused one.
    """
    by_place = collections.defaultdict(list)
    for item in obligations:
        by_place[(item["file"], item["line"], item["kind"])].append(item)

    def take(check, exact):
        candidates = [
            item
            for item in by_place.get(
                (check["file"], check["line"], check["kind"]), []
            )
            if not item["used"]
        ]
        if exact:
            candidates = [
                item for item in candidates if item["column"] == check["column"]
            ]
        if not candidates:
            return None
        chosen = min(
            candidates, key=lambda item: abs(item["column"] - check["column"])
        )
        chosen["used"] = True
        return chosen

    # GNATprove reports the initialization of an object once, at its
    # declaration; AdaLang checks every read, and an out parameter at the
    # subprogram's exit. The obligations about one declaration are taken
    # together, and the object is as good as the worst of them.
    by_subject = collections.defaultdict(list)
    for item in obligations:
        if item["kind"] == "initialization-check" and item["subject"]:
            by_subject[item["subject"]].append(item)
    for check in checks:
        if check["check"] == "initialization of":
            group = by_subject.get(
                (check["file"], check["line"], check["column"]))
            if group:
                for item in group:
                    item["used"] = True
                check["match"] = min(
                    group, key=lambda item: WORST_FIRST.index(item["status"]))
                check["grouped"] = len(group)

    for exact in (True, False):
        for check in checks:
            if check["kind"] is not None and check.get("match") is None:
                check["match"] = take(check, exact)

    files_with_obligations = {item["file"] for item in obligations}
    lines_with = collections.defaultdict(set)
    for item in obligations:
        lines_with[(item["file"], item["kind"])].add(item["line"])
    kinds_at = collections.defaultdict(set)
    for item in obligations:
        kinds_at[(item["file"], item["line"])].add(item["kind"])

    for check in checks:
        match = check.get("match")
        check["reason"] = ""
        if check["file"] not in files_with_obligations:
            check["adalang"] = "file without any obligation"
        elif check["kind"] is None:
            check["adalang"] = "no such obligation kind"
        elif match is not None:
            check["adalang"] = match["status"]
            check["reason"] = match["reason"]
        else:
            # Say how far off AdaLang is: the same kind a few lines away
            # (a different idea of where the check is), another kind on
            # the same line (a different idea of what the check is), or
            # nothing.
            check["adalang"] = "no obligation here"
            near = lines_with.get((check["file"], check["kind"]), set())
            if any(abs(line - check["line"]) <= NEARBY and line != check["line"]
                   for line in near):
                check["reason"] = "same kind within %d lines" % NEARBY
            elif any(item["used"] for item in by_place.get(
                    (check["file"], check["line"], check["kind"]), [])):
                check["reason"] = "fewer obligations of this kind on the line"
            elif kinds_at.get((check["file"], check["line"])):
                check["reason"] = "another kind on this line"
            else:
                check["reason"] = "nothing on this line"


# The verdict on an object when its obligations disagree.
WORST_FIRST = ["definite-error", "unproved", "unsupported", "unreachable",
               "proved-safe"]

OUTCOMES = [
    "proved-safe",
    "unproved",
    "unsupported",
    "definite-error",
    "unreachable",
    "no obligation here",
    "no such obligation kind",
    "file without any obligation",
]


def table(rows, header):
    lines = ["| " + " | ".join(header) + " |"]
    lines.append("| --- |" + " ---: |" * (len(header) - 1))
    for row in rows:
        lines.append("| " + " | ".join(str(cell) for cell in row) + " |")
    return "\n".join(lines)


def share(part, whole):
    return "n/a" if whole == 0 else "%.1f%%" % (100.0 * part / whole)


def report(name, checks, obligations, other):
    proved = [check for check in checks if check["verdict"] == "proved"]
    open_checks = [check for check in checks if check["verdict"] == "not proved"]
    justified = [check for check in checks if check["verdict"] == "justified"]

    out = []
    out.append(f"## {name}")
    out.append("")
    instances = sum(check["instances"] for check in checks)
    out.append(
        f"GNATprove reports {len(checks)} checks ({instances} messages, a "
        f"check of a generic unit being repeated for each instance): "
        f"{len(proved)} proved, {len(justified)} justified by the corpus, "
        f"{len(open_checks)} not proved. AdaLang raises {len(obligations)} "
        f"obligations."
    )
    out.append("")

    # 1. What AdaLang did with each check GNATprove proved.
    outcome = collections.Counter(check["adalang"] for check in proved)
    out.append("### Checks GNATprove proved")
    out.append("")
    out.append(
        table(
            [
                (label, outcome[label], share(outcome[label], len(proved)))
                for label in OUTCOMES
                if outcome[label]
            ],
            ("AdaLang", "Checks", "Share"),
        )
    )
    out.append("")

    # 2. The same, by GNATprove check.
    by_check = collections.defaultdict(collections.Counter)
    for check in proved:
        by_check[check["check"]][check["adalang"]] += 1
    rows = []
    for label, counts in sorted(
        by_check.items(), key=lambda entry: -sum(entry[1].values())
    ):
        total = sum(counts.values())
        rows.append(
            (
                label,
                total,
                counts["proved-safe"],
                counts["unproved"],
                counts["unsupported"],
                counts["no obligation here"]
                + counts["no such obligation kind"]
                + counts["file without any obligation"],
                counts["definite-error"],
            )
        )
    out.append(
        table(
            rows,
            (
                "GNATprove check",
                "Proved",
                "AdaLang proved",
                "Unproved",
                "Unsupported",
                "No obligation",
                "Definite error",
            ),
        )
    )
    out.append("")

    # 3. Why the undecided ones are undecided.
    missing = collections.Counter(
        check["reason"] for check in proved
        if check["adalang"] == "no obligation here"
    )
    if missing:
        out.append("Where AdaLang has no obligation of the kind at the place:")
        out.append("")
        out.append(
            table(
                [(reason, count) for reason, count in missing.most_common()],
                ("What AdaLang has instead", "Checks"),
            )
        )
        out.append("")

    reasons = collections.Counter(
        (check["adalang"], check["reason"] or "(no reason recorded)")
        for check in proved
        if check["adalang"] in ("unproved", "unsupported")
    )
    out.append("Reasons AdaLang gives where it has an obligation but no verdict:")
    out.append("")
    out.append(
        table(
            [
                (status, reason, count)
                for (status, reason), count in reasons.most_common(12)
            ],
            ("Status", "Reason", "Checks"),
        )
    )
    out.append("")

    # 4. Soundness: the two cells that must stay empty.
    unsound = [check for check in open_checks if check["adalang"] == "proved-safe"]
    false_alarm = [check for check in proved if check["adalang"] == "definite-error"]
    out.append("### Disagreements")
    out.append("")
    out.append(
        f"- AdaLang proved, GNATprove did not: {len(unsound)}"
        + "".join(
            f"\n  - `{c['file']}:{c['line']}:{c['column']}` {c['check']}"
            for c in unsound[:20]
        )
    )
    out.append(
        f"- AdaLang reports a definite error, GNATprove proved: {len(false_alarm)}"
        + "".join(
            f"\n  - `{c['file']}:{c['line']}:{c['column']}` {c['check']}"
            for c in false_alarm[:20]
        )
    )
    out.append("")

    # 5. What AdaLang raises that GNATprove has no check for.
    extra = collections.Counter(
        (item["kind"], item["status"]) for item in obligations if not item["used"]
    )
    kinds = sorted({kind for kind, _ in extra})
    out.append("### AdaLang obligations without a GNATprove check")
    out.append("")
    out.append(
        table(
            [
                (
                    kind,
                    sum(extra[(kind, s)] for s in OUTCOMES),
                    extra[(kind, "proved-safe")],
                    extra[(kind, "unproved")],
                    extra[(kind, "unsupported")],
                )
                for kind in kinds
            ],
            ("Kind", "Obligations", "Proved", "Unproved", "Unsupported"),
        )
    )
    out.append("")
    if other:
        out.append(
            "GNATprove messages not counted as checks: "
            + "; ".join(f"{text} ({count})" for text, count in other.most_common(8))
            + "."
        )
        out.append("")
    return "\n".join(out)


def write_rows(path, name, checks, obligations, append=False):
    header = (
        "corpus\tfile\tline\tcolumn\tgnatprove_check\tgnatprove\t"
        "adalang_kind\tadalang\treason\n"
    )
    fresh = not append or os.path.getsize(path) == 0
    with open(path, "a" if append else "w") as rows:
        if fresh:
            rows.write(header)
        for check in checks:
            rows.write(
                "\t".join(
                    str(cell)
                    for cell in (
                        name,
                        check["file"],
                        check["line"],
                        check["column"],
                        check["check"],
                        check["verdict"],
                        check["kind"] or "",
                        check["adalang"],
                        check["reason"],
                    )
                )
                + "\n"
            )
        for item in obligations:
            if not item["used"]:
                rows.write(
                    "\t".join(
                        str(cell)
                        for cell in (
                            name,
                            item["file"],
                            item["line"],
                            item["column"],
                            "",
                            "no check",
                            item["kind"],
                            item["status"],
                            item["reason"],
                        )
                    )
                    + "\n"
                )


def overall(corpora):
    """The totals over several corpora: (name, checks, obligations) each."""
    proved = [
        check
        for _, checks, _ in corpora
        for check in checks
        if check["verdict"] == "proved"
    ]
    open_checks = [
        check
        for _, checks, _ in corpora
        for check in checks
        if check["verdict"] == "not proved"
    ]
    out = ["## All corpora", ""]
    out.append(
        f"GNATprove proves {len(proved)} checks on these "
        f"{len(corpora)} corpora. What AdaLang does with each of them:"
    )
    out.append("")
    outcome = collections.Counter(check["adalang"] for check in proved)
    out.append(
        table(
            [
                (label, outcome[label], share(outcome[label], len(proved)))
                for label in OUTCOMES
                if outcome[label]
            ],
            ("AdaLang", "Checks", "Share"),
        )
    )
    out.append("")
    rows = []
    for name, checks, _ in corpora:
        mine = [check for check in checks if check["verdict"] == "proved"]
        counts = collections.Counter(check["adalang"] for check in mine)
        rows.append(
            (
                name,
                len(mine),
                counts["proved-safe"],
                counts["unproved"],
                counts["unsupported"],
                counts["no obligation here"],
                counts["no such obligation kind"],
                counts["file without any obligation"],
            )
        )
    out.append(
        table(
            rows,
            (
                "Corpus",
                "Proved by GNATprove",
                "AdaLang proved",
                "Unproved",
                "Unsupported",
                "No obligation here",
                "No such kind",
                "File without obligations",
            ),
        )
    )
    out.append("")
    unsound = sum(1 for check in open_checks if check["adalang"] == "proved-safe")
    false_alarm = sum(1 for check in proved if check["adalang"] == "definite-error")
    out.append(
        f"Disagreements: {unsound} checks AdaLang proved that GNATprove did "
        f"not, {false_alarm} definite errors on checks GNATprove proved."
    )
    out.append("")
    return "\n".join(out)


def load(name, adalang, gnatprove):
    checks, other = read_gnatprove(gnatprove)
    obligations = read_adalang(adalang)
    pair(checks, obligations)
    return name, checks, obligations, other


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("adalang", nargs="?")
    parser.add_argument("gnatprove", nargs="?")
    parser.add_argument("--name", default="corpus")
    parser.add_argument("--rows")
    parser.add_argument(
        "--corpus",
        action="append",
        default=[],
        metavar="NAME=RESULTS_DIR",
        help="a corpus whose results directory holds adalang-verify.json and "
        "gnatprove-prove.oneline; may be repeated, and the totals over all "
        "of them are printed first",
    )
    arguments = parser.parse_args()

    loaded = []
    for item in arguments.corpus:
        name, _, directory = item.partition("=")
        loaded.append(
            load(
                name,
                os.path.join(directory, "adalang-verify.json"),
                os.path.join(directory, "gnatprove-prove.oneline"),
            )
        )
    if arguments.adalang and arguments.gnatprove:
        loaded.append(load(arguments.name, arguments.adalang, arguments.gnatprove))
    if not loaded:
        parser.error("give a report and a log, or --corpus")

    if len(loaded) > 1:
        print(overall([(n, c, o) for n, c, o, _ in loaded]))
    for name, checks, obligations, other in loaded:
        print(report(name, checks, obligations, other))
    if arguments.rows:
        with open(arguments.rows, "w"):
            pass
        for name, checks, obligations, _ in loaded:
            write_rows(arguments.rows, name, checks, obligations, append=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
