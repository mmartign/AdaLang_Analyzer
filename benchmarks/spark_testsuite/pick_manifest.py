#!/usr/bin/env python3
"""Second stage: from the ~1k raw candidates, pick a balanced ~120-unit
manifest. Clean tests are the oracle; weak tests are unsoundness tripwires
(AdaLang must never call 'safe' a location GNATprove reports medium/high).
"""
import os, re, sys
from collections import Counter, defaultdict

TESTS = sys.argv[1]
TARGET_CLEAN = 90
TARGET_WEAK = 35

# Units whose committed test.out is not a sound oracle at this toolchain and
# are therefore excluded by hand after the automated pick.
#   W316-007__string_multidim: GNATprove's baseline reports the line-13
#     aggregate range checks as proved, but GNAT (15.3) raises
#     CONSTRAINT_ERROR there at run time (dim-1 bounds 6..8 vs index subtype
#     4..7 on a null multidim array), so GNATprove is not trustworthy
#     ground truth for this unit. (The AdaLang false positive it used to
#     trigger on the now-dead "pragma Assert (False)" is fixed -- FP-065 --
#     but the oracle-soundness problem stands, so the unit stays excluded.)
HAND_EXCLUDE = {"W316-007__string_multidim"}

SCALAR_MEDIUM = ("overflow check", "range check", "index check",
                 "division check", "divide by zero", "length check",
                 "discriminant check")
WHEEL = ["overflow check", "range check", "index check", "division check",
         "divide by zero", "length check", "discriminant check",
         "loop invariant", "loop variant", "is not initialized",
         "initialization check"]
RARE = {"loop_variant", "discriminant", "divide_by_zero", "initialization",
        "is_not_initialized", "length"}
MSG_RE = re.compile(r"([\w.-]+\.ad[bs]):(\d+):\d+:\s+"
                    r"(info|warning|low|medium|high|error)\b(.*)$")


def read(p):
    try:
        return open(p, "r", errors="replace").read()
    except OSError:
        return ""


def analyse(name):
    d = os.path.join(TESTS, name)
    out = read(os.path.join(d, "test.out"))
    srcs = [e for e in os.listdir(d) if re.search(r"\.ad[bs]$", e)]
    loc = sum(read(os.path.join(d, s)).count("\n") + 1 for s in srcs)
    kinds, medium_kinds = set(), set()
    n_med = n_high = 0
    for line in out.splitlines():
        m = MSG_RE.search(line)
        if not m:
            continue
        v, rest = m.group(3), m.group(4).lower()
        for k in WHEEL:
            if k in rest:
                tag = k.replace(" check", "").replace(" ", "_")
                kinds.add(tag)
                if v in ("medium", "high"):
                    medium_kinds.add(tag)
        if v == "medium":
            n_med += 1
        elif v == "high":
            n_high += 1
    return {"test": name, "loc": loc, "n_src": len(srcs), "kinds": kinds,
            "medium_kinds": medium_kinds, "n_med": n_med, "n_high": n_high}


def main():
    rows = []
    with open("candidates.tsv") as f:
        next(f)
        for line in f:
            c = line.rstrip("\n").split("\t")
            rows.append({"test": c[0], "class": c[1]})

    clean = [analyse(r["test"]) for r in rows if r["class"] == "clean"]
    weak = [analyse(r["test"]) for r in rows if r["class"] == "weak"]

    # ---- clean: maximise kind diversity, keep small, cap per signature ----
    def clean_score(a):
        s = len(a["kinds"]) * 2
        s += sum(3 for k in a["kinds"] if k in RARE)
        s -= a["loc"] / 120.0
        s -= max(0, a["n_src"] - 2)
        return s

    clean = [a for a in clean if a['test'] not in HAND_EXCLUDE]
    weak = [a for a in weak if a['test'] not in HAND_EXCLUDE]
    clean.sort(key=clean_score, reverse=True)
    picked_clean, sig_count, kindcov = [], Counter(), Counter()
    for a in clean:
        if a["loc"] > 400:
            continue
        sig = tuple(sorted(a["kinds"]))
        if sig_count[sig] >= 4:
            continue
        picked_clean.append(a)
        sig_count[sig] += 1
        kindcov.update(a["kinds"])
        if len(picked_clean) >= TARGET_CLEAN:
            break

    # ---- weak: small, few mediums, medium must be a scalar kind ----------
    def weak_ok(a):
        return (a["loc"] <= 300 and a["n_src"] <= 3
                and 1 <= (a["n_med"] + a["n_high"]) <= 4
                and a["medium_kinds"]
                and a["medium_kinds"] <= {
                    "overflow", "range", "index", "division",
                    "divide_by_zero", "length", "discriminant"})

    weak_ok_list = [a for a in weak if weak_ok(a)]
    weak_ok_list.sort(key=lambda a: (len(a["medium_kinds"]) == 0, a["loc"]))
    picked_weak, wsig = [], Counter()
    for a in weak_ok_list:
        sig = tuple(sorted(a["medium_kinds"]))
        if wsig[sig] >= 6:
            continue
        picked_weak.append(a)
        wsig[sig] += 1
        if len(picked_weak) >= TARGET_WEAK:
            break

    with open("MANIFEST.tsv", "w") as f:
        f.write("# test_dir\tclass\tn_src\tloc\tobligation_kinds\n")
        for a in sorted(picked_clean, key=lambda x: x["test"]):
            f.write(f"{a['test']}\tclean\t{a['n_src']}\t{a['loc']}\t"
                    f"{','.join(sorted(a['kinds']))}\n")
        for a in sorted(picked_weak, key=lambda x: x["test"]):
            f.write(f"{a['test']}\tweak\t{a['n_src']}\t{a['loc']}\t"
                    f"{','.join(sorted(a['medium_kinds']))}\n")

    print(f"picked clean : {len(picked_clean)}")
    print(f"picked weak  : {len(picked_weak)}")
    print(f"total        : {len(picked_clean) + len(picked_weak)}")
    print(f"clean LOC    : min {min(a['loc'] for a in picked_clean)}, "
          f"max {max(a['loc'] for a in picked_clean)}, "
          f"sum {sum(a['loc'] for a in picked_clean)}")
    print("\nclean kind coverage:")
    for k, n in kindcov.most_common():
        print(f"  {n:4d}  {k}")
    print("\nweak medium-kind coverage:")
    wc = Counter()
    for a in picked_weak:
        wc.update(a["medium_kinds"])
    for k, n in wc.most_common():
        print(f"  {n:4d}  {k}")


if __name__ == "__main__":
    main()
