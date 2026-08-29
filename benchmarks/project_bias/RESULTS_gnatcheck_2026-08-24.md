# project_bias: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-08-29, part of a full ten-corpus refresh ahead of a version
bump (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`
for the batch's shared methodology).

## Environment

- Corpus: EliAvila10/project_bias at
  `bb83565322eba9a0bd59ccda607edcdc0a1bd381` (`PROJECT_BIAS_REVISION`),
  unchanged.
- AdaLang Analyzer: commit `c43415f`.
- GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `PROJECT_BIAS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/project_bias/run_gnatcheck.sh`.

## First attempt crashed; retry succeeded

The first attempt hit the recurring `STORAGE_ERROR: stack overflow`
(`gnatcheck: error: unparsable worker output`) crash class at the very
start of `gnatcheck.txt`, though processing continued afterward and still
produced 303 result lines. Per this project's standing policy for that
crash class, a second, unmodified re-run was done rather than trusting the
crashed attempt; it completed with zero internal-issue lines and totals
bit-identical to the 2026-08-24 run (below) — consistent with from-source-
build flakiness, not a real regression.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 225 | |
| &nbsp;&nbsp;matched by GNATcheck | 168 | 74.7% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 57 | 25.3% |
| GNATcheck findings (mapped rules) | 299 | |
| &nbsp;&nbsp;matched by AdaLang | 168 | 56.2% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 131 | 43.8% |

Bit-identical to the 2026-08-24 run in every field.

## `Empty_Then_Body`/`Empty_Else_Body`/`Empty_Elsif_Body`/`Null_Case_Alternative` results

All four still report **0 findings** on this corpus, both sides — unchanged
from every prior run.

## Caveats

Same caveats as the 2026-08-24 run apply unchanged (line-granularity
matching; `Floating_Equality`/`float_equality_checks` and
`Redundant_Boolean_Comparison`/`redundant_boolean_expressions`'s clean
large matches).
