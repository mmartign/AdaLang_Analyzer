# Saatana: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-09-22, verifying the `FP-066` fix (`Null_Statement`) across
every corpus this project's GNATcheck oracle comparison covers -- see
`benchmarks/aws/RESULTS_gnatcheck_2026-09-22.md` for the full root-cause
writeup and methodology; this file only records this corpus's numbers.

## Environment

- Corpus: HeisenbugLtd/Saatana at `7ba07e735498de39216a30479c3d2cc0817f03ac`
  (`SAATANA_REVISION`), unchanged.
- AdaLang Analyzer: commit including the `FP-066` fix (version 1.5.2).
- Reproduce: `SAATANA_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/saatana/run_gnatcheck.sh`.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 157 | |
| &nbsp;&nbsp;matched by GNATcheck | 96 | 61.1% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 61 | 38.9% |
| GNATcheck findings (mapped rules) | 129 | |
| &nbsp;&nbsp;matched by AdaLang | 96 | 74.4% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 33 | 25.6% |

## `Null_Statement`: FP-066 fix confirmed

Before: 1 finding, unmatched (0%). After: **0 findings** -- the single
finding was the sole-statement idiom now exempted. AdaLang's total
mapped-rule finding count dropped 158 -> 157 accordingly.

## Caveats

Same caveats as prior runs apply unchanged.
