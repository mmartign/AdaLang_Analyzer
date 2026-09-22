# Tokeneer: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-09-22, verifying the `FP-066` fix (`Null_Statement`) across
every corpus this project's GNATcheck oracle comparison covers -- see
`benchmarks/aws/RESULTS_gnatcheck_2026-09-22.md` for the full root-cause
writeup and methodology; this file only records this corpus's numbers.

## Environment

- Corpus: AdaCore/spark2014 (sparse Tokeneer checkout) at
  `a97467e91a16409c866434fcc7a5f553bbd98b8a` (`TOKENEER_REVISION`),
  unchanged.
- AdaLang Analyzer: commit including the `FP-066` fix (version 1.5.2).
- Reproduce: `TOKENEER_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/tokeneer/run_gnatcheck.sh`. Clean run, no internal-issue lines.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 569 | |
| &nbsp;&nbsp;matched by GNATcheck | 444 | 78.0% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 125 | 22.0% |
| GNATcheck findings (mapped rules) | 1602 | |
| &nbsp;&nbsp;matched by AdaLang | 425 | 26.5% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 1177 | 73.5% |

## `Null_Statement`: FP-066 fix confirmed

Before: 30 findings, all 30 unmatched (0%). After: **0 findings** -- every
one was the sole-statement idiom now exempted. AdaLang's total mapped-rule
finding count dropped 599 -> 569 accordingly.

## Caveats

Same caveats as prior runs apply unchanged.
