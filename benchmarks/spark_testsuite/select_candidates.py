#!/usr/bin/env python3
"""Curate a candidate subset of the AdaCore SPARK2014 gnatprove testsuite for
use as an AdaLang Analyzer --verify independent-oracle benchmark corpus.

Selection is by *obligation kind*, decided from the test's own sources and its
committed test.out baseline -- never from how AdaLang scores it.
"""
import os, re, sys, json

TESTS = sys.argv[1]

# --- exclusion predicates -------------------------------------------------
FLOW = "__flow"
UG = "ug__"

YAML_DISQUALIFY = ("large", "replay", "session_opt", "contains_manual_proof",
                   "sparklib", "do_flow", "codepeer")

# GNATprove check kinds that are AdaLang --verify's bounded-scalar wheelhouse
WHEELHOUSE = [
    "overflow check", "range check", "index check", "division check",
    "divide by zero", "length check", "discriminant check",
    "loop invariant", "loop variant",
    'is not initialized', "initialization check",
]
# Kinds that mean "AdaLang will just say Unsupported" -> low oracle yield
OUT_OF_SCOPE_HINTS = [
    "pointer", "access-to", "ownership", "memory leak", "memory accessibility",
    "tasking", "ceiling priority", "nontermination", "call to nonreturning",
    "termination", "container", "resource or memory leak",
]

MSG_RE = re.compile(r":\d+:\d+:\s+(info|warning|low|medium|high|error)\b(.*)$")


def read(path):
    try:
        with open(path, "r", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def classify(testdir):
    name = os.path.basename(testdir)
    entries = os.listdir(testdir)

    if FLOW in name:
        return None, "flow-test"
    if name.startswith(UG):
        return None, "ug-test"
    if "test.py" in entries:
        return None, "custom-test.py"
    if "proof" in entries and os.path.isdir(os.path.join(testdir, "proof")):
        return None, "replay/session"
    if "test.out" not in entries:
        return None, "no-baseline"
    if any(e.endswith(".gpr") for e in entries):
        return None, "own-gpr"          # v1: default-project tests only

    yaml = read(os.path.join(testdir, "test.yaml"))
    if yaml:
        low = yaml.lower()
        if any(k in low for k in YAML_DISQUALIFY):
            return None, "yaml-disqualify"

    srcs = [e for e in entries if re.search(r"\.ad[bs]$", e)]
    if not srcs:
        return None, "no-ada-sources"
    if len(srcs) > 12:
        return None, "too-many-src-files"

    src_text = "\n".join(read(os.path.join(testdir, s)) for s in srcs)
    if re.search(r'with\s+"sparklib"', src_text, re.I) or \
       "SPARK.Containers" in src_text or "SPARK.Big_Integers" in src_text:
        return None, "sparklib-dep"

    # Exclude units that pull in a heavy library unit whose obligations
    # AdaLang cannot model at all (formal containers, big numbers) or that
    # only add runtime-closure noise (bounded/unbounded strings). run.sh
    # scopes GNATprove's output to each unit's own files, so ordinary
    # runtime withs (Text_IO, Interfaces, sibling packages) are fine and
    # stay in.
    HEAVY = ("ada.containers", "spark.containers", "spark.big_",
             "ada.strings.unbounded", "ada.strings.bounded",
             "ada.numerics", "ada.strings.maps", "ada.finalization")
    for m in re.finditer(r'^\s*(?:limited\s+|private\s+)?with\s+([\w.]+)',
                         src_text, re.I | re.M):
        u = m.group(1).lower().rstrip(".")
        if any(u == h or u.startswith(h) for h in HEAVY):
            return None, "withs-heavy-library-unit"
    loc = src_text.count("\n") + 1
    if loc > 900:
        return None, "too-large"

    out = read(os.path.join(testdir, "test.out"))

    has_error = bool(re.search(r":\d+:\d+:\s+error\b", out))
    if has_error:
        return None, "legality/compile-error test"

    # unexpected-exception / warning-only baselines are not obligation tests
    kinds = set()
    verdicts = {"info": 0, "medium": 0, "high": 0, "low": 0, "warning": 0}
    for line in out.splitlines():
        m = MSG_RE.search(line)
        if not m:
            continue
        v, rest = m.group(1), m.group(2).lower()
        if v in verdicts:
            verdicts[v] += 1
        for k in WHEELHOUSE:
            if k in rest:
                kinds.add(k.replace(" check", "").replace(" ", "_"))

    wheel_hits = sum(1 for k in WHEELHOUSE if k in out.lower())
    oos_hits = sum(1 for k in OUT_OF_SCOPE_HINTS if k in out.lower())

    if wheel_hits == 0:
        return None, "no-scalar-obligations-in-baseline"
    if oos_hits > wheel_hits:
        return None, "dominated-by-out-of-scope-checks"

    unproved = verdicts["medium"] + verdicts["high"]
    cls = "clean" if unproved == 0 else "weak"

    return {
        "test": name,
        "class": cls,
        "n_src": len(srcs),
        "loc": loc,
        "kinds": ",".join(sorted(kinds)) or "-",
        "info": verdicts["info"],
        "medium": verdicts["medium"],
        "high": verdicts["high"],
        "warning": verdicts["warning"],
        "yaml": "y" if yaml else "",
    }, None


def main():
    kept, reasons = [], {}
    for name in sorted(os.listdir(TESTS)):
        d = os.path.join(TESTS, name)
        if not os.path.isdir(d):
            continue
        row, why = classify(d)
        if row is None:
            reasons[why] = reasons.get(why, 0) + 1
        else:
            kept.append(row)

    cols = ["test", "class", "n_src", "loc", "kinds", "info", "medium", "high",
            "warning", "yaml"]
    with open("candidates.tsv", "w") as f:
        f.write("\t".join(cols) + "\n")
        for r in kept:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")

    print(f"total test dirs scanned : {sum(reasons.values()) + len(kept)}")
    print(f"candidates kept         : {len(kept)}")
    clean = [r for r in kept if r['class'] == 'clean']
    weak = [r for r in kept if r['class'] == 'weak']
    print(f"  clean (full oracle)   : {len(clean)}")
    print(f"  weak  (has mediums)   : {len(weak)}")
    print()
    print("excluded, by reason:")
    for why, n in sorted(reasons.items(), key=lambda kv: -kv[1]):
        print(f"  {n:5d}  {why}")
    print()
    from collections import Counter
    kc = Counter()
    for r in kept:
        for k in r["kinds"].split(","):
            kc[k] += 1
    print("kind coverage across candidates:")
    for k, n in kc.most_common():
        print(f"  {n:5d}  {k}")


if __name__ == "__main__":
    main()
