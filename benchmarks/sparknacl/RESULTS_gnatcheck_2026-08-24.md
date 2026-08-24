# SPARKNaCl: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Second run, part of the 2026-08-24 batch re-run across all ten corpora
following the `Empty_Then_Body`/`Empty_Else_Body` addition and the `FP-059`
fix (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`
for the full writeup of that fix and the batch's shared methodology).

## Environment

- Corpus: rod-chapman/SPARKnaCl at `49e3bddf092561ce2b74c134a35acff91a2da9a4`
  (`SPARKNACL_REVISION`), unchanged from the 2026-08-19 run.
- AdaLang Analyzer / GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `SPARKNACL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/sparknacl/run_gnatcheck.sh`.

## First attempt crashed outright; retry succeeded

The first attempt hit the recurring `STORAGE_ERROR: stack overflow` crash
class (`gnatcheck: error: unparsable worker output`) early enough that only
476 of the eventual ~2150 `gnatcheck.txt` lines were produced — unlike
`ada_drivers_library`'s 2026-08-19 run, where the crash let processing
continue afterward, this one effectively killed the batch. A second,
unmodified re-run completed with only one residual internal-issue line and
totals consistent with the 2026-08-19 run (see below) — consistent with
this being from-source-build flakiness, not a real regression.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 1557 | |
| &nbsp;&nbsp;matched by GNATcheck | 1332 | 85.5% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 225 | 14.5% |
| GNATcheck findings (mapped rules) | 1629 | |
| &nbsp;&nbsp;matched by AdaLang | 1332 | 81.8% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 297 | 18.2% |

Close to the 2026-08-19 run (85.7%/75.9% then), within this build's known
run-to-run variance.

## `Empty_Then_Body`/`Empty_Else_Body`/`Empty_Elsif_Body`/`Null_Case_Alternative` results

All four report **0 findings** on this corpus, both sides (`null_paths`
itself: 0 GNATcheck findings too) — this small, disciplined SPARK codebase
simply doesn't contain the "empty branch/alternative with a real sibling"
shape, the same true-negative result as `Empty_If_Body`/`Empty_Elsif_Body`
showed here in the 2026-08-19 run.

## Caveats

Same caveats as every prior run apply unchanged (line-granularity matching,
rule pairs are name-level matches not proven semantic equivalence).
