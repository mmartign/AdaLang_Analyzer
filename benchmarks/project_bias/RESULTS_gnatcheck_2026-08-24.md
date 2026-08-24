# project_bias: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Second run, part of the 2026-08-24 batch re-run across all ten corpora
following the `Empty_Then_Body`/`Empty_Else_Body` addition and the `FP-059`
fix (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`).

## Environment

- Corpus: EliAvila10/project_bias at
  `bb83565322eba9a0bd59ccda607edcdc0a1bd381` (`PROJECT_BIAS_REVISION`),
  unchanged from the 2026-08-19 run.
- AdaLang Analyzer / GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `PROJECT_BIAS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/project_bias/run_gnatcheck.sh`. Clean run, no crashes.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 225 | |
| &nbsp;&nbsp;matched by GNATcheck | 168 | 74.7% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 57 | 25.3% |
| GNATcheck findings (mapped rules) | 299 | |
| &nbsp;&nbsp;matched by AdaLang | 168 | 56.2% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 131 | 43.8% |

Close to the 2026-08-19 run (73.3%/62.7% then), within this build's known
run-to-run variance.

## `Empty_Then_Body`/`Empty_Else_Body`/`Empty_Elsif_Body`/`Null_Case_Alternative` results

All four report **0 findings** on this corpus, both sides — the same
true-negative result as `sparknacl`, `cubedos`, and `libkeccak` in this
batch.

## Caveats

Same caveats as the 2026-08-19 run apply unchanged (line-granularity
matching; `Floating_Equality`/`float_equality_checks` and
`Redundant_Boolean_Comparison`/`redundant_boolean_expressions`'s clean
large matches, already the series' first, unaffected by this run).
