#!/usr/bin/env python3
"""Regenerate quality/corpus_exercise_coverage.tsv from the committed
benchmark result JSON under benchmark-results/.

For every Rule_Kind check it records whether at least one benchmark preset
run enabled it over an external, independently authored corpus, which presets
and how many corpora did, and how many findings across how many distinct
files it produced there. This is exercise evidence -- the check was actually
run against real Ada, not only against repository fixtures -- not a soundness
or completeness claim.

Deterministic: inputs are sorted, output column order is fixed, no host
state. tests/run_corpus_exercise_coverage.sh fails if the committed file is
not byte-identical to this script's output (and skips when python3 is
unavailable).

Usage: python3 tests/gen_corpus_exercise_coverage.py > quality/corpus_exercise_coverage.tsv
"""

import glob
import json
import os
import sys

PRESETS = ("recommended", "spark", "automotive", "verify")


def catalogue(rules_ads):
    out, inside = [], False
    for line in open(rules_ads):
        if "type Rule_Kind is (" in line:
            inside = True
            continue
        if inside:
            s = line.strip()
            if s.startswith(");"):
                break
            tok = s.rstrip(",").strip()
            if tok:
                out.append(tok)
    return out


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    checks = catalogue(os.path.join(root, "src", "adalang_analyzer-rules.ads"))

    presets_of = {c: set() for c in checks}
    corpora_of = {c: set() for c in checks}
    findings_of = {c: 0 for c in checks}
    files_of = {c: set() for c in checks}
    unknown = set()

    for d in sorted(glob.glob(os.path.join(root, "benchmark-results", "*", ""))):
        corpus = os.path.basename(d.rstrip(os.sep))
        for p in PRESETS:
            fn = os.path.join(d, "adalang-%s.json" % p)
            if not os.path.exists(fn):
                continue
            j = json.load(open(fn))
            for r in j.get("analysisConfiguration", {}).get("enabledRules", []):
                if r in presets_of:
                    presets_of[r].add(p)
                    corpora_of[r].add(corpus)
                else:
                    unknown.add(r)
            for f in j.get("findings", []):
                r = f.get("ruleId")
                if r in findings_of:
                    findings_of[r] += 1
                    files_of[r].add(f.get("file"))
                elif r:
                    unknown.add(r)

    if unknown:
        sys.stderr.write("rule ids in benchmark results not in the catalogue: "
                         + ", ".join(sorted(unknown)) + "\n")
        return 1

    corpora_scanned = sorted({
        os.path.basename(d.rstrip(os.sep))
        for d in glob.glob(os.path.join(root, "benchmark-results", "*", ""))
        if any(os.path.exists(os.path.join(d, "adalang-%s.json" % p))
               for p in PRESETS)
    })

    out = sys.stdout
    out.write("# corpora scanned (%d): %s\n"
              % (len(corpora_scanned), ",".join(corpora_scanned)))
    out.write("# check\texercised\tpresets\tcorpora\tfindings\tfiles\n")
    for c in checks:
        yes = bool(presets_of[c])
        out.write("\t".join((
            c,
            "yes" if yes else "no",
            ",".join(sorted(presets_of[c])) if yes else "-",
            str(len(corpora_of[c])),
            str(findings_of[c]),
            str(len(files_of[c])),
        )) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
