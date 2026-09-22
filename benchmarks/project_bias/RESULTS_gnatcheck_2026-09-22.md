# project_bias: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-09-22, verifying the `FP-066` fix (`Null_Statement`) across
every corpus this project's GNATcheck oracle comparison covers -- see
`benchmarks/aws/RESULTS_gnatcheck_2026-09-22.md` for the full root-cause
writeup and methodology; this file only records this corpus's numbers.

## Environment

- Corpus: EliAvila10/project_bias at
  `bb83565322eba9a0bd59ccda607edcdc0a1bd381` (`PROJECT_BIAS_REVISION`),
  unchanged.
- AdaLang Analyzer: commit including the `FP-066` fix (version 1.5.2).
- Reproduce: `PROJECT_BIAS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/project_bias/run_gnatcheck.sh`.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 225 | |
| &nbsp;&nbsp;matched by GNATcheck | 168 | 74.7% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 57 | 25.3% |
| GNATcheck findings (mapped rules) | 299 | |
| &nbsp;&nbsp;matched by AdaLang | 168 | 56.2% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 131 | 43.8% |

## `Null_Statement`: no change (already clean)

0 findings before and after -- this corpus had no instance of the FP-066
idiom to begin with, so `Null_Statement` was already at 0/0 and is
unaffected by the fix. All totals are identical to the 2026-08-29 run.

## Caveats

Same caveats as prior runs apply unchanged.
