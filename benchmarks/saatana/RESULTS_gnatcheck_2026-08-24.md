# Saatana: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-08-29, part of a full ten-corpus refresh ahead of a version
bump (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`
for the batch's shared methodology). Completed cleanly on the first
attempt, no crash.

## Environment

- Corpus: HeisenbugLtd/Saatana at `7ba07e735498de39216a30479c3d2cc0817f03ac`
  (`SAATANA_REVISION`), unchanged.
- AdaLang Analyzer: commit `c43415f`.
- GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `SAATANA_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/saatana/run_gnatcheck.sh`.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 158 | |
| &nbsp;&nbsp;matched by GNATcheck | 96 | 60.8% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 62 | 39.2% |
| GNATcheck findings (mapped rules) | 129 | |
| &nbsp;&nbsp;matched by AdaLang | 96 | 74.4% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 33 | 25.6% |

AdaLang's own finding count and the matched-pair count (96) are unchanged
from the 2026-08-24 run. GNATcheck's own finding count moved from 120 to
129 (74.4% matched vs. 80.0% before) — consistent with this from-source
build's documented run-to-run variance, not a corpus or AdaLang change.

## `Empty_Then_Body` result: same benign reporting-location gap

`Empty_Else_Body`/`Empty_Elsif_Body` still show 0/0 on this corpus.
`Empty_Then_Body` still shows 1 finding (`saatana-crypto-phelix.adb:420`),
0% GNATcheck-side match — the same reporting-location convention
difference documented in `gnatcoll/RESULTS_gnatcheck_2026-08-24.md`, not a
new bug.

## Caveats

Same caveats as prior runs apply unchanged (line-granularity matching;
small-corpus sample size).
