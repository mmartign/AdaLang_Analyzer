# Libkeccak: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-09-22, verifying the `FP-066` fix (`Null_Statement`) across
every corpus this project's GNATcheck oracle comparison covers -- see
`benchmarks/aws/RESULTS_gnatcheck_2026-09-22.md` for the full root-cause
writeup and methodology; this file only records this corpus's numbers.

## Environment

- Corpus: damaki/libkeccak at `4b7174fccbf5461998b18395aaeecc68bb25798d`
  (`LIBKECCAK_REVISION`), unchanged; reconfigured with `alr build`.
- AdaLang Analyzer: commit including the `FP-066` fix (version 1.5.2).
- Reproduce: `LIBKECCAK_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/libkeccak/run_gnatcheck.sh`.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 1460 | |
| &nbsp;&nbsp;matched by GNATcheck | 1235 | 84.6% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 225 | 15.4% |
| GNATcheck findings (mapped rules) | 1475 | |
| &nbsp;&nbsp;matched by AdaLang | 1235 | 83.7% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 240 | 16.3% |

## `Null_Statement`: no change (already clean)

0 findings before and after -- this corpus had no instance of the FP-066
idiom to begin with, so `Null_Statement` was already at 0/0 and is
unaffected by the fix. AdaLang's total mapped-rule finding count is
unchanged (1460).

## Caveats

Same caveats as prior runs apply unchanged.
