# Ada_Drivers_Library: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-08-29, part of a full ten-corpus refresh ahead of a version
bump. Clean run, no crashes.

## Environment

- Corpus: AdaCore/Ada_Drivers_Library at
  `81c04806d267fc12116a6f746c8e05012cef0484` (`ADL_REVISION`), unchanged.
- AdaLang Analyzer: commit `c43415f`.
- GNATcheck: same from-source local build as prior runs.
- Rule map / comparator: `benchmarks/gnatcheck_rule_map.tsv` (41 pairs) /
  `benchmarks/gnatcheck_compare.awk`, unchanged logic.
  `recursive_subprograms`/`No_Recursion` excluded as in every prior run.
- Reproduce: `ADL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/ada_drivers_library/run_gnatcheck.sh`.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 859 | |
| &nbsp;&nbsp;matched by GNATcheck | 378 | 44.0% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 481 | 56.0% |
| GNATcheck findings (mapped rules) | 1087 | |
| &nbsp;&nbsp;matched by AdaLang | 378 | 34.8% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 709 | 65.2% |

AdaLang's own finding count and the matched-pair count (378) are unchanged
from the 2026-08-24 run. GNATcheck's own finding count moved slightly
(1071 → 1087, 35.3% → 34.8% matched) — within this from-source build's
documented run-to-run variance.

## `Empty_Then_Body`/`Empty_Else_Body` results: `FP-059` fix still holds

Both still show 0/0/n/a on this corpus, confirming the `FP-059` fix (a
solitary `pragma Assert (False);` correctly counted as substantive, not
treated as an empty branch) continues to hold with no regression.
`Empty_If_Body`/`Empty_Elsif_Body` also still show 0/0/n/a.
`Null_Case_Alternative` shows 4 findings, 0% GNATcheck-side match — not
investigated further this run (same reporting-location convention
category documented on other corpora in this batch, not re-verified here
since this run's purpose was the standard refresh, not new investigation).

## Caveats

Same caveats as prior runs apply unchanged (two synthetic GPR projects for
same-basename board-variant files, `Dependency_Limit` uninformative on
this corpus, line-granularity matching, rule pairs are name-level matches
not proven semantic equivalence).
