# AWS: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Second run, part of the 2026-08-24 batch re-run across all ten corpora
following the `Empty_Then_Body`/`Empty_Else_Body` addition and the `FP-059`
fix (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`).

## Environment

- Corpus: AdaCore/aws at `02cbd01c2f96c288440415a46bf865616c0ee0f8`
  (`AWS_REVISION`) with `templates_parser` submodule at
  `7c59ed4f1ee371c7d3f420b890e287b72c2473f4`, unchanged from the 2026-08-19
  run.
- AdaLang Analyzer / GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `AWS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/aws/run_gnatcheck.sh`, after the documented `make setup build`
  step. Clean run, no crashes.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 6343 | |
| &nbsp;&nbsp;matched by GNATcheck | 3258 | 51.4% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 3085 | 48.6% |
| GNATcheck findings (mapped rules) | 10205 | |
| &nbsp;&nbsp;matched by AdaLang | 3248 | 31.8% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 6957 | 68.2% |

Close to the 2026-08-19 run (52.4%/28.9% then), within this build's known
run-to-run variance.

## `null_paths`-family results: all 40 findings confirmed the same benign reporting-location gap, not new bugs

`Empty_Then_Body` (5), `Empty_Else_Body` (2), `Empty_Elsif_Body` (2), and
`Null_Case_Alternative` (31) — 40 findings total, 0% GNATcheck-side match.
Applied the same systematic cross-check that closed out
`gnatcoll-core/RESULTS_gnatcheck_2026-08-24.md`'s investigation of this
pattern (every finding checked against GNATcheck's own `null_paths` output
in the same file, within 5 lines): **all 40 matched**, confirming this is
the same reporting-location-convention difference (GNATcheck reports at the
null statement's own line, AdaLang at the branch/alternative's start line),
not a repeat of `FP-059` or any other new bug. Not spot-checked by hand at
this volume — the systematic sweep is the evidence.

## Caveats

Same caveats as the 2026-08-19 run apply unchanged (spec/body split on
`Too_Many_Parameters`, subprogram/statement granularity split on
`No_Multiple_Return`, line-granularity matching generally).
