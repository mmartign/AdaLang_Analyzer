# Saatana: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Second run, part of the 2026-08-24 batch re-run across all ten corpora
following the `Empty_Then_Body`/`Empty_Else_Body` addition and the `FP-059`
fix (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`).

## Environment

- Corpus: HeisenbugLtd/Saatana at `7ba07e735498de39216a30479c3d2cc0817f03ac`
  (`SAATANA_REVISION`), unchanged from the 2026-08-19 run.
- AdaLang Analyzer / GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `SAATANA_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/saatana/run_gnatcheck.sh`.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 158 | |
| &nbsp;&nbsp;matched by GNATcheck | 96 | 60.8% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 62 | 39.2% |
| GNATcheck findings (mapped rules) | 120 | |
| &nbsp;&nbsp;matched by AdaLang | 96 | 80.0% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 24 | 20.0% |

Matches the 2026-08-19 run exactly (61.1%/80.0% then, within rounding).

## `Empty_Then_Body` result: same benign reporting-location gap

`Empty_Else_Body`/`Empty_Elsif_Body`/`Null_Case_Alternative` all show 0/0
on this corpus. `Empty_Then_Body` shows 1 finding
(`saatana-crypto-phelix.adb:420`, 0% GNATcheck-side match), confirmed to
have a matching GNATcheck `null_paths` finding one line below (`:421:10`)
— the same reporting-location convention difference documented in full in
`gnatcoll/RESULTS_gnatcheck_2026-08-24.md`, not a new bug.

## Caveats

Same caveats as the 2026-08-19 run apply unchanged (line-granularity
matching; small-corpus sample size).
