# Tokeneer: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-08-29, part of a full ten-corpus refresh ahead of a version
bump (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`
for the batch's shared methodology). Clean run, no crashes.

## Environment

- Corpus: AdaCore/spark2014 (sparse checkout on
  `testsuite/gnatprove/tests/tokeneer`) at
  `a97467e91a16409c866434fcc7a5f553bbd98b8a` (`TOKENEER_REVISION`),
  unchanged.
- AdaLang Analyzer: commit `c43415f`.
- GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `TOKENEER_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/tokeneer/run_gnatcheck.sh`.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 599 | |
| &nbsp;&nbsp;matched by GNATcheck | 444 | 74.1% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 155 | 25.9% |
| GNATcheck findings (mapped rules) | 1602 | |
| &nbsp;&nbsp;matched by AdaLang | 425 | 26.5% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 1177 | 73.5% |

Bit-identical to the 2026-08-24 run in every field.

## `Empty_Else_Body`/`Null_Case_Alternative` results: same benign reporting-location gap

Still 1 `Empty_Else_Body` finding (`userentry.adb:389`) and 2
`Null_Case_Alternative` findings (`enclave.adb:1909`, `tokenreader.adb:597`)
— 0% GNATcheck-side match for all three, the same reporting-location
convention gap documented in `gnatcoll/RESULTS_gnatcheck_2026-08-24.md`,
not a new bug. `Empty_Then_Body`/`Empty_Elsif_Body` still show 0/0.

## Caveats

Same caveats as prior runs apply unchanged (line-granularity matching;
`Exception_Swallowed`/`Empty_Exception_Handler` reaching 100% match at
volume).
