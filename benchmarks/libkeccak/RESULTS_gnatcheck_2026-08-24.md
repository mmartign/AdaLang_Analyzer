# libkeccak: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Second run, part of the 2026-08-24 batch re-run across all ten corpora
following the `Empty_Then_Body`/`Empty_Else_Body` addition and the `FP-059`
fix (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`).

## Environment

- Corpus: damaki/libkeccak at `4b7174fccbf5461998b18395aaeecc68bb25798d`
  (`LIBKECCAK_REVISION`), unchanged from the 2026-08-19 run.
- AdaLang Analyzer / GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `LIBKECCAK_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/libkeccak/run_gnatcheck.sh`, after `alr build` in the corpus
  checkout. Clean run, no crashes.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 1460 | |
| &nbsp;&nbsp;matched by GNATcheck | 1244 | 85.2% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 216 | 14.8% |
| GNATcheck findings (mapped rules) | 1556 | |
| &nbsp;&nbsp;matched by AdaLang | 1244 | 79.9% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 312 | 20.1% |

Close to the 2026-08-19 run (83.8%/90.4% then), within this build's known
run-to-run variance (this run's GNATcheck-side total, 1556, differs
slightly from the earlier 1354 — the recurring `STORAGE_ERROR` crash class
affects raw counts run to run, as documented throughout this directory).

## `Empty_Then_Body`/`Empty_Else_Body`/`Empty_Elsif_Body`/`Null_Case_Alternative` results

All four report **0 findings** on this corpus, both sides (`null_paths`
itself: 0 GNATcheck findings too) — the same true-negative result as
`sparknacl`, `cubedos`, and `project_bias` in this batch.

## Caveats

Same caveats as the 2026-08-19 run apply unchanged (line-granularity
matching; `Magic_Number`/`numeric_literals` reaching 100% GNATcheck-side
match at volume, already the series high, unaffected by this run).
