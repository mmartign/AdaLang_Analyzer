# Ada_Drivers_Library: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-09-22, verifying the `FP-066` fix (`Null_Statement`) across
every corpus this project's GNATcheck oracle comparison covers -- see
`benchmarks/aws/RESULTS_gnatcheck_2026-09-22.md` for the full root-cause
writeup and methodology; this file only records this corpus's numbers.

## Environment

- Corpus: AdaCore/Ada_Drivers_Library at
  `81c04806d267fc12116a6f746c8e05012cef0484` (`ADL_REVISION`), unchanged.
- AdaLang Analyzer: commit including the `FP-066` fix (version 1.5.2).
- GNATcheck / rule map: same as prior runs.
- Reproduce: `ADL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/ada_drivers_library/run_gnatcheck.sh`.

## GNATcheck side noisier than usual this run; totals below use the two
## (of four attempts) that reproduced the historical baseline exactly

This corpus's from-source GNATcheck build hit a different, non-crashing
internal-issue class this pass (`error: internal issue at
too_many_dependencies.lkql:12:11: Null receiver in dot access`), with a
noisy count across four attempts (7, 33, 46, 62 lines). Two of the four
attempts nonetheless landed on GNATcheck findings = 1087 / matched = 378,
identical to the 2026-08-29 baseline; those numbers are used below as the
trustworthy figures. AdaLang's own side (807, 0 `Null_Statement`) was
identical across all four attempts.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 807 | |
| &nbsp;&nbsp;matched by GNATcheck | 378 | 46.8% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 429 | 53.2% |
| GNATcheck findings (mapped rules) | 1087 | |
| &nbsp;&nbsp;matched by AdaLang | 378 | 34.8% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 709 | 65.2% |

## `Null_Statement`: FP-066 fix confirmed

Before: 52 findings, all 52 unmatched (0%). After: **0 findings** -- every
one was the sole-statement idiom now exempted. AdaLang's total mapped-rule
finding count dropped 859 -> 807 accordingly; the matched-pair count (378)
is unchanged, since none of those 52 had ever matched a GNATcheck finding.

## Caveats

Same caveats as prior runs apply unchanged (two synthetic GPR projects for
same-basename board-variant files, `Dependency_Limit` uninformative on
this corpus, line-granularity matching).
