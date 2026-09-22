# AWS: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-09-22, verifying the `FP-066` fix (`Null_Statement`) found while
triaging this corpus's still-unmatched GNATcheck gaps (see
`benchmarks/README.md`'s "GNATcheck oracle comparison" caveats). Not part of
a full ten-corpus refresh -- only this corpus was re-run; the other nine
still carry their 2026-08-29 numbers and are expected to show a similar,
unmeasured `Null_Statement` improvement whenever they are next refreshed.

## Environment

- Corpus: AdaCore/aws at `02cbd01c2f96c288440415a46bf865616c0ee0f8`
  (`AWS_REVISION`) with `templates_parser` submodule at
  `7c59ed4f1ee371c7d3f420b890e287b72c2473f4`, unchanged.
- AdaLang Analyzer: commit including the `FP-066` fix (version 1.5.2).
- GNATcheck / rule map: same as prior runs.
- Reproduce: `AWS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/aws/run_gnatcheck.sh`, after the documented `make setup build`
  step.

## First two attempts crashed; third retry succeeded

Both the before-fix and after-fix comparison runs hit the recurring
`STORAGE_ERROR: stack overflow` (`gnatcheck: error: unparsable worker
output`) crash class on their first attempt. Per this project's standing
policy for that crash class, unmodified re-runs were done; the after-fix
run needed a second retry (three attempts total) before completing with
zero internal-issue lines and a GNATcheck total (11617) matching the
2026-08-29 baseline exactly. Its totals are used below.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 6255 | |
| &nbsp;&nbsp;matched by GNATcheck | 3335 | 53.3% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 2920 | 46.7% |
| GNATcheck findings (mapped rules) | 11617 | |
| &nbsp;&nbsp;matched by AdaLang | 3325 | 28.6% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 8292 | 71.4% |

GNATcheck's own finding count (11617) and the matched-pair counts (3335 /
3325) are unchanged from the 2026-08-29 run, confirming the fix did not
touch anything GNATcheck agreed with. AdaLang's own finding count dropped
from 6343 to 6255 (-88), entirely accounted for by `Null_Statement` (see
below); since none of those 88 had ever matched a GNATcheck finding, the
match-rate improvement (52.6% -> 53.3%) is a pure noise reduction, not new
agreement.

## `Null_Statement`: FP-066 fix confirmed, 88/88 false positives eliminated

Before the fix: 88 `Null_Statement` findings, 0 matched by GNATcheck's
`redundant_null_statements` (0%). After: **0 findings** -- every one of
AWS's 88 was the sole-statement idiom (`exception when X => null;` or a
single-choice `when K => null;` case branch) that GNATcheck's own rule
already exempts and that AdaLang now exempts too (see `FP-066` in
`quality/known_analysis_issues.tsv`). GNATcheck's own `redundant_null_statements`
still shows 4 unmatched findings, all in files outside this corpus's own
source tree (`gnatcoll-*`, `sax-*`, `schema-*` -- dependency/runtime units
pulled in by GNATcheck's project-closure analysis that AdaLang does not
analyze in this benchmark's scope); not investigated further, since it is
an analysis-scope difference rather than a `Null_Statement` logic gap.

## `Deep_Nesting`: explained, not a bug

Still 0% exact-line match (49 AdaLang findings, 119 GNATcheck findings,
unchanged by this fix -- `Deep_Nesting` was not touched). Root-caused via
both tools' own source: GNATcheck's `overly_nested_control_structures`
fires once per over-nested control-structure *node* (so one deep chain
yields several findings, each at that construct's own line), while
AdaLang's `Deep_Nesting` computes one maximum-depth value per *subprogram*
and reports a single finding at the subprogram's name line. Different
granularity, different report location, and a different default threshold
(GNATcheck's `n=3` vs. AdaLang's `4`) -- three independent, structural
reasons an exact `(file, line)` match is essentially impossible, none of
them a defect. See `docs/src/gnatcheck-rule-comparison.md`.

## `null_paths`-family results: unchanged from the 2026-08-24 investigation

Still 40 findings total across `Empty_Then_Body` (5), `Empty_Else_Body`
(2), `Empty_Elsif_Body` (2), and `Null_Case_Alternative` (31) — identical
counts to the prior run; not re-investigated this pass (unrelated to this
run's purpose).

## Caveats

Same caveats as prior runs apply unchanged (spec/body split on
`Too_Many_Parameters`, subprogram/statement granularity split on
`No_Multiple_Return`, line-granularity matching generally).
