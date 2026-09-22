# SPARKNaCl: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-09-22, verifying the `FP-066` fix (`Null_Statement`) across
every corpus this project's GNATcheck oracle comparison covers -- see
`benchmarks/aws/RESULTS_gnatcheck_2026-09-22.md` for the full root-cause
writeup and methodology; this file only records this corpus's numbers.

## Environment

- Corpus: rod-chapman/SPARKnaCl at `49e3bddf092561ce2b74c134a35acff91a2da9a4`
  (`SPARKNACL_REVISION`), unchanged.
- AdaLang Analyzer: commit including the `FP-066` fix (version 1.5.2).
- Reproduce: `SPARKNACL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/sparknacl/run_gnatcheck.sh`.

## GNATcheck side noisier than usual this run

Four attempts were needed to reproduce a matched-pair count (1334) at or
above every prior recorded run; two of the four landed on GNATcheck
findings = 1758 / matched = 1334, used below (the other two, 1332 matched
against 1609 and 1629 GNATcheck findings respectively, are within this
corpus's own already-documented run-to-run variance -- see
`RESULTS_gnatcheck_2026-08-29.md`). AdaLang's own side (1557, 0
`Null_Statement`) was identical across all four attempts.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 1557 | |
| &nbsp;&nbsp;matched by GNATcheck | 1334 | 85.7% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 223 | 14.3% |
| GNATcheck findings (mapped rules) | 1758 | |
| &nbsp;&nbsp;matched by AdaLang | 1334 | 75.9% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 424 | 24.1% |

## `Null_Statement`: no change (already clean)

0 findings before and after -- this corpus had no instance of the FP-066
idiom to begin with, so `Null_Statement` was already at 0/0 and is
unaffected by the fix. AdaLang's total mapped-rule finding count is
unchanged (1557).

## Caveats

Same caveats as prior runs apply unchanged.
