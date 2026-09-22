# CubedOS: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-09-22, verifying the `FP-066` fix (`Null_Statement`) across
every corpus this project's GNATcheck oracle comparison covers -- see
`benchmarks/aws/RESULTS_gnatcheck_2026-09-22.md` for the full root-cause
writeup and methodology; this file only records this corpus's numbers.

## Environment

- Corpus: cubesatlab/cubedos at `c402301000a5a92237e0f7ab106186a48273cf24`
  (`CUBEDOS_REVISION`), unchanged.
- AdaLang Analyzer: commit including the `FP-066` fix (version 1.5.2).
- Reproduce: `CUBEDOS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/cubedos/run_gnatcheck.sh`. Clean run, no internal-issue lines.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 177 | |
| &nbsp;&nbsp;matched by GNATcheck | 157 | 88.7% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 20 | 11.3% |
| GNATcheck findings (mapped rules) | 653 | |
| &nbsp;&nbsp;matched by AdaLang | 157 | 24.0% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 496 | 76.0% |

## `Null_Statement`: FP-066 fix confirmed

Before: 5 findings, all 5 unmatched (0%). After: **0 findings** -- every
one was the sole-statement idiom now exempted. AdaLang's total mapped-rule
finding count dropped 182 -> 177 accordingly.

## Caveats

Same caveats as prior runs apply unchanged.
