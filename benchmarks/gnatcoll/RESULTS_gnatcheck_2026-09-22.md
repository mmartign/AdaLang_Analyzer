# gnatcoll-core: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-09-22, verifying the `FP-066` fix (`Null_Statement`) across
every corpus this project's GNATcheck oracle comparison covers -- see
`benchmarks/aws/RESULTS_gnatcheck_2026-09-22.md` for the full root-cause
writeup and methodology; this file only records this corpus's numbers.

## Environment

- Corpus: AdaCore/gnatcoll-core at `9f6ffb394793b0ac098fb1e9b206a659680788b3`
  (`GNATCOLL_REVISION`), unchanged.
- AdaLang Analyzer: commit including the `FP-066` fix (version 1.5.2).
- GNATcheck / rule map: same as prior runs.
- Reproduce: `GNATCOLL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/gnatcoll/run_gnatcheck.sh`.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 1847 | |
| &nbsp;&nbsp;matched by GNATcheck | 1029 | 55.7% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 818 | 44.3% |
| GNATcheck findings (mapped rules) | 2523 | |
| &nbsp;&nbsp;matched by AdaLang | 1027 | 40.7% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 1496 | 59.3% |

## `Null_Statement`: FP-066 fix confirmed

Before: 45 findings, 44 unmatched (2%). After: **1 finding, 0 unmatched
(100%)** -- 44 of the 45 were the sole-statement idiom now exempted;
the one that remains is genuine redundant padding and, tellingly, is now
correctly matched by GNATcheck's own `redundant_null_statements` (which
also dropped from 1 unmatched to 0), the same idiom-aware agreement seen
on every other corpus. AdaLang's total mapped-rule finding count dropped
1891 -> 1847 accordingly.

GNATcheck's own finding count (2523) is well above the 2026-08-29 baseline
(2191); this from-source build's already-documented run-to-run variance
(one internal-issue line this run), not a corpus or AdaLang change.

## Caveats

Same caveats as prior runs apply unchanged.
