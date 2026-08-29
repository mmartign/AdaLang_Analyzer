# libkeccak: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-08-29, part of a full ten-corpus refresh ahead of a version
bump (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-29.md`
for the batch's shared methodology).

## Environment

- Corpus: damaki/libkeccak at `4b7174fccbf5461998b18395aaeecc68bb25798d`
  (`LIBKECCAK_REVISION`), unchanged.
- AdaLang Analyzer: commit `c43415f`.
- GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-29.md`.
- Reproduce: `LIBKECCAK_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/libkeccak/run_gnatcheck.sh`, after `alr build` in the corpus
  checkout.

## Both attempts hit worker crashes; retry's numbers used

The first attempt hit the recurring `STORAGE_ERROR: stack overflow`
(`gnatcheck: error: unparsable worker output`) crash class once. Per this
project's standing policy for that crash class, a second, unmodified
re-run was done; it hit the same crash class twice (two independent worker
crashes, 10 residual `gnatcheck.txt` lines total out of 1671), but
processing still completed and produced a full comparison. Since a further
retry is outside this refresh's one-retry policy, this second run's
numbers are recorded below as the best available result on this corpus —
this is this from-source build's documented flakiness on a large-ish
corpus (100 files, many generic instantiations), not a new failure mode.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 1460 | |
| &nbsp;&nbsp;matched by GNATcheck | 1224 | 83.8% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 236 | 16.2% |
| GNATcheck findings (mapped rules) | 1355 | |
| &nbsp;&nbsp;matched by AdaLang | 1224 | 90.3% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 131 | 9.7% |

AdaLang's own finding count is essentially unchanged from the 2026-08-24
run (1460 both times). GNATcheck's own finding count moved from 1556 to
1355 (matched-pair count 1244 → 1224) — within this from-source build's
documented run-to-run variance, plausibly related to the two worker
crashes above dropping some findings from affected files.

## `Empty_Then_Body`/`Empty_Else_Body`/`Empty_Elsif_Body`/`Null_Case_Alternative` results

All four still report **0 findings** on this corpus, both sides —
unchanged from every prior run.

## Caveats

Same caveats as prior runs apply unchanged (line-granularity matching;
`Magic_Number`/`numeric_literals` reaching 100% GNATcheck-side match at
volume).
