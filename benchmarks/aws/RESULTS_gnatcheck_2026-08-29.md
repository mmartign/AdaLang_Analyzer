# AWS: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-08-29, part of a full ten-corpus refresh ahead of a version
bump (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-29.md`
for the batch's shared methodology).

## Environment

- Corpus: AdaCore/aws at `02cbd01c2f96c288440415a46bf865616c0ee0f8`
  (`AWS_REVISION`) with `templates_parser` submodule at
  `7c59ed4f1ee371c7d3f420b890e287b72c2473f4`, unchanged.
- AdaLang Analyzer: commit `c43415f`.
- GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-29.md`.
- Reproduce: `AWS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/aws/run_gnatcheck.sh`, after the documented `make setup build`
  step.

## First attempt crashed; retry succeeded

The first attempt hit the recurring `STORAGE_ERROR: stack overflow`
(`gnatcheck: error: unparsable worker output`) crash class (10 residual
lines). Per this project's standing policy for that crash class, a second,
unmodified re-run was done; it completed with zero internal-issue lines.
Its totals are used below.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 6343 | |
| &nbsp;&nbsp;matched by GNATcheck | 3335 | 52.6% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 3008 | 47.4% |
| GNATcheck findings (mapped rules) | 11617 | |
| &nbsp;&nbsp;matched by AdaLang | 3325 | 28.6% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 8292 | 71.4% |

AdaLang's own finding count is unchanged from the 2026-08-24 run (6343).
GNATcheck's own finding count moved further than most other corpora this
batch (10205 → 11617, matched-pair count 3248 → 3325) — within this
from-source build's documented run-to-run variance, but on the larger side;
this is this project's largest corpus by file count (348 files) and the
one most exposed to the crash class's effect on raw counts.

## `null_paths`-family results: unchanged from the 2026-08-24 investigation

Still 40 findings total across `Empty_Then_Body` (5), `Empty_Else_Body`
(2), `Empty_Elsif_Body` (2), and `Null_Case_Alternative` (31) — identical
counts to the prior run. The 2026-08-24 run's systematic cross-check
(every finding confirmed against a GNATcheck `null_paths` finding in the
same file within 5 lines) was not re-run this pass since the finding set
itself is unchanged and the conclusion (benign reporting-location
convention gap, not a bug) already stands; not re-investigated per this
refresh's scope.

## Caveats

Same caveats as prior runs apply unchanged (spec/body split on
`Too_Many_Parameters`, subprogram/statement granularity split on
`No_Multiple_Return`, line-granularity matching generally).
