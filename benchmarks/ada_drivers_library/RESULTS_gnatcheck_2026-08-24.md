# Ada_Drivers_Library: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Fifth run of the GNATcheck oracle comparison, and the first since
`Empty_Then_Body`/`Empty_Else_Body` were added (2026-08-24), which grew the
rule map from 39 to 41 pairs. Purpose: give the two new `null_paths`
sub-checks the same live-corpus treatment `Empty_If_Body`/`Empty_Elsif_Body`
already got in the 2026-08-19 run below, rather than shipping them with only
self-analysis and hand-written precision-corpus evidence.

## Environment

- Corpus: AdaCore/Ada_Drivers_Library at
  `81c04806d267fc12116a6f746c8e05012cef0484` (`ADL_REVISION`), unchanged
  from the 2026-08-19 run.
- AdaLang Analyzer: built from a working tree at
  `10531a2a6b66764758531df240b5dc0c9d2bb68c` plus this session's
  `Empty_Then_Body`/`Empty_Else_Body`-family fixes (the `Has_Substantive_Statement`
  pragma-Assert fix below; committed alongside this file).
- GNATcheck: `gnatcheck 27.0w`, same from-source local build as prior runs.
- Rule map / comparator: `benchmarks/gnatcheck_rule_map.tsv` (now 41 pairs)
  / `benchmarks/gnatcheck_compare.awk`, unchanged logic.
  `recursive_subprograms`/`No_Recursion` excluded as in every prior run.
- Reproduce: `ADL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/ada_drivers_library/run_gnatcheck.sh`.

## Found and fixed: `Empty_Else_Body` false positive on `pragma Assert (False)`

`Empty_Else_Body` flagged `arch/ARM/STM32/drivers/dma2d/stm32-dma2d-interrupt.adb:109`:

```ada
elsif DMA2D_Periph.ISR.TCIF then
   ...
else
   --  Unexpected interrupt.
   pragma Assert (False);
end if;
```

GNATcheck's `null_paths` correctly does not flag this line. A solitary
`pragma Assert (False);` is a deliberate "this must never happen" runtime
guard, not filler — treating it the same as a bare `null;` was wrong.
Root-caused to the check-family's shared `Has_Substantive_Statement` helper
(`src/adalang_analyzer-checks-control_flow.adb`), not `Empty_Else_Body`
specifically: it treated every pragma, without exception, as non-substantive.
The identical false positive was independently confirmed reachable through
all five checks sharing that helper (`Empty_If_Body`, `Empty_Elsif_Body`,
`Empty_Then_Body`, `Empty_Else_Body`, `Null_Case_Alternative`) by direct
construction of one fixture per check — not just argued from code
inspection.

Fixed by special-casing `pragma Assert` specifically to count as
substantive, leaving every other pragma (`Unreferenced`, `Warnings`,
`Import`, `Inline`, ...) unaffected. Verified both ways by toggling the fix
off and back on against all five new precision-corpus fixtures (each
correctly reports a finding pre-fix, clean post-fix). Logged as `FP-059` in
`quality/known_analysis_issues.tsv`.

## Totals (34 AdaLang rules / 34 GNATcheck rules, post-fix)

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 859 | |
| &nbsp;&nbsp;matched by GNATcheck | 378 | 44.0% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 481 | 56.0% |
| GNATcheck findings (mapped rules) | 1071 | |
| &nbsp;&nbsp;matched by AdaLang | 378 | 35.3% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 693 | 64.7% |

Same run-to-run variance caveat as every prior run on this from-source
GNATcheck build applies (`Total gnatcheck failures: 3` this run, vs. 7 on
this same corpus five days earlier) — treat exact counts as approximate,
this document's qualitative finding as the reliable part. Full per-rule
table: `benchmark-results/ada_drivers_library/gnatcheck-comparison.txt`
from the run this document reports (not committed — `benchmark-results/`
is git-ignored; re-run the script to regenerate it).

## `Empty_Then_Body`/`Empty_Else_Body` results, post-fix

| AdaLang rule | Match | AdaLang-N | AdaOnly | AdaMatch% |
| --- | --- | ---: | ---: | ---: |
| `Empty_Then_Body` | close | 0 | 0 | n/a |
| `Empty_Else_Body` | close | 0 | 0 | n/a |

Both now agree with `null_paths` at zero findings each on this corpus
(post-fix) — a true negative on both sides, not an untested pair: the
`pragma Assert` shape above is the only candidate either check could have
flagged on this corpus, and the fix correctly suppresses it while nothing
else in the driver tree matches either check's remaining scope. Consistent
with `Empty_If_Body`/`Empty_Elsif_Body`, which also show 0/0/n/a here (see
the 2026-08-19 run below) — this driver tree simply doesn't otherwise
contain the "empty then/else with a real sibling branch" shape at all,
independent of this fix.

## Caveats

- Same caveats as the 2026-08-19 run below apply unchanged (two synthetic
  GPR projects, `Dependency_Limit` uninformative on this corpus, line-
  granularity matching, rule pairs are name-level matches not proven
  semantic equivalence).
- This run's sole purpose was live-corpus coverage for the two new checks;
  it was not used to re-investigate any of the already-explained
  reporting-convention effects (spec/body split, subprogram/statement
  granularity) documented in the 2026-08-19 run.
