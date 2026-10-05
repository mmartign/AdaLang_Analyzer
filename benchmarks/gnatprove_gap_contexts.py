#!/usr/bin/env python3
"""Say what construct each missing obligation of a gap ledger is in.

Reads the rows a gnatprove_gap_ledger.py run wrote with --rows, takes the
checks GNATprove proved for which AdaLang has no obligation, and groups them
by the construct at that place: inside a Pre or Post aspect, a slice, an
actual parameter, a declaration, and so on. The construct comes from
bin/describe_locations (benchmarks/tools/describe_locations.gpr), which
parses the sources; no project is needed.

Usage:
    gnatprove_gap_contexts.py ROWS.tsv NAME=SOURCE_ROOT [NAME=SOURCE_ROOT ...]

Each NAME is a corpus name as it appears in ROWS.tsv, SOURCE_ROOT a
directory under which its sources are found. Prints Markdown.
"""

import collections
import csv
import os
import subprocess
import sys

MISSING = ("no obligation here", "no such obligation kind",
           "file without any obligation")

# The constructs that say most about why an obligation is missing, looked
# for from the inside out.
EXPRESSION_FORMS = ("slice", "loop-range", "subtype-indication",
                    "subtype-declaration", "aggregate", "argument",
                    "qualified-expression", "quantified-expression",
                    "conditional-expression")
STATEMENT_FORMS = ("object-declaration", "component-declaration",
                   "parameter-declaration", "assignment-value",
                   "assignment-target", "return", "call-statement",
                   "condition", "case", "type-declaration", "instantiation")


def group_of(context):
    parts = context.split(" < ")
    for part in parts:
        if part.startswith("aspect:"):
            return "in aspect " + part[7:]
    for part in parts:
        if part.startswith("pragma:"):
            return "in pragma " + part[7:]
    for part in parts[1:]:
        if part in EXPRESSION_FORMS:
            return part
        if part.startswith("attribute:"):
            return "attribute prefix or argument"
    for part in parts[1:]:
        if part in STATEMENT_FORMS:
            return part
    return parts[-1] if len(parts) > 1 else parts[0]


def find_sources(roots):
    index = {}
    for name, root in roots.items():
        for directory, _, files in os.walk(root):
            for filename in files:
                if filename.endswith((".ads", ".adb")):
                    index.setdefault((name, filename),
                                     os.path.join(directory, filename))
    return index


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    roots = dict(item.split("=", 1) for item in sys.argv[2:])
    sources = find_sources(roots)

    rows = []
    with open(sys.argv[1]) as table:
        for row in csv.DictReader(table, delimiter="\t"):
            if row["gnatprove"] == "proved" and row["adalang"] in MISSING:
                path = sources.get((row["corpus"], row["file"]))
                if path:
                    row["path"] = path
                    rows.append(row)

    tool = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "..", "bin", "describe_locations")
    request = "".join(
        f"{row['path']}\t{row['line']}\t{row['column']}\n" for row in rows)
    answer = subprocess.run([tool], input=request, capture_output=True,
                            text=True, check=True).stdout.splitlines()
    if len(answer) != len(rows):
        sys.exit("describe_locations answered %d of %d locations"
                 % (len(answer), len(rows)))

    by_group = collections.Counter()
    by_check = collections.defaultdict(collections.Counter)
    for row, line in zip(rows, answer):
        group = group_of(line.split("\t")[3])
        by_group[group] += 1
        by_check[row["gnatprove_check"]][group] += 1

    print(f"{len(rows)} checks GNATprove proved have no AdaLang obligation "
          f"at their place. By the construct they are in:")
    print()
    print("| Construct | Checks |")
    print("| --- | ---: |")
    for group, count in by_group.most_common(25):
        print(f"| {group} | {count} |")
    print()
    print("By GNATprove check, with the constructs it is most often in:")
    print()
    print("| GNATprove check | Checks | Where |")
    print("| --- | ---: | --- |")
    for check, groups in sorted(by_check.items(),
                                key=lambda item: -sum(item[1].values())):
        where = ", ".join(f"{group} {count}"
                          for group, count in groups.most_common(5))
        print(f"| {check} | {sum(groups.values())} | {where} |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
